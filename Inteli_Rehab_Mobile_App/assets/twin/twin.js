// Digital-twin scene: a rigged arm whose forearm bone follows the band's
// elbow angle. Driven from Flutter through window.twin (see below); every
// setter only stores a target - the render loop eases toward it, so ~31 Hz
// samples look smooth and a burst of calls costs nothing.
//
// Served from a root that holds both /twin/ and /models/, so the model is
// fetched as ../models/Arm_{L,R}.gltf.
(function () {
  "use strict";
  var T = window.ThreeBundle;
  var params = new URLSearchParams(location.search);

  function post(type, detail) {
    // Flutter's JavaScriptChannel (named Twin); absent in a plain browser.
    try {
      if (window.Twin && window.Twin.postMessage) {
        window.Twin.postMessage(JSON.stringify({ type: type, detail: detail || null }));
      }
    } catch (e) { /* the host channel must never break rendering */ }
  }

  if (!T) { post("error", "three_bundle.js did not load"); return; }

  // --- config the host can override via twin.configure / URL params -------
  var cfg = {
    side: params.get("side") === "right" ? "right" : "left",
    // Which local axis of the forearm bone is the elbow's hinge, and which
    // direction is flexion. Bone rest orientations in this rig are
    // arbitrary, so these are found empirically in dev mode (?dev=1).
    axis: params.get("axis") || "x",
    sign: params.get("sign") === "-1" ? -1 : 1,
    offsetDeg: Number(params.get("offset")) || 0,
    azimuthDeg: params.get("az") !== null ? Number(params.get("az")) : 90, // camera angle around the arm
    tierColors: { normal: "#4C9F70", needsCorrection: "#E7A24C", unsafe: "#D96248" },
    emgHot: "#D96248",
    // Muscle colour by effort (%MVC) - the same blue/green/orange/red as the
    // app's MuscleActivationBar, so the arm and the bar always agree.
    muscleStops: [[0, "#3B82F6"], [20, "#4C9F70"], [45, "#E7A24C"], [80, "#D96248"]],
    bulge: 0.014, // how far the biceps swells at full effort, in model units
    elbowBlend: 0.18, // half-width of the bend zone, as a fraction of forearm length
    easing: 0.35, // fraction of the remaining gap closed per 60 Hz frame
  };

  var renderer, scene, camera;
  var clock = new T.Clock();
  var forearm = null, upperArm = null, restQuat = null;
  var skinMat = null, bicepMat = null, tricepMat = null;
  var bicepBase = null, tricepBase = null;
  var model = null, armMesh = null, framing = null;
  var loadToken = 0, paused = false, rafId = 0, ready = false;
  var devReadout = null;

  var state = {
    elbowTarget: Number(params.get("elbow")) || 0, elbowNow: Number(params.get("elbow")) || 0,
    bicepTarget: Number(params.get("emg")) || 0, bicepNow: Number(params.get("emg")) || 0,
    tricepTarget: 0, tricepNow: 0,
    tier: "normal",
  };

  function init() {
    renderer = new T.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0x000000, 0);
    document.body.appendChild(renderer.domElement);

    scene = new T.Scene();
    camera = new T.PerspectiveCamera(30, 1, 0.01, 50);
    scene.add(new T.HemisphereLight(0xffffff, 0x8899aa, 1.1));
    var sun = new T.DirectionalLight(0xffffff, 1.4);
    // Lights ride on the camera so the arm is lit from the viewer's side
    // whatever angle the camera ends up at.
    sun.position.set(1, 2, 3);
    camera.add(sun);
    scene.add(camera);

    window.addEventListener("resize", resize);
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) stopLoop();
      else if (!paused) startLoop();
    });
    resize();
    loadModel();
    startLoop();
    if (params.get("dev") === "1") buildDevPanel();
  }

  function resize() {
    var w = window.innerWidth || 300, h = window.innerHeight || 300;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    frameCamera();
  }

  function loadModel() {
    var token = ++loadToken;
    ready = false;
    if (model) { scene.remove(model); model = null; }
    forearm = upperArm = restQuat = null;
    skinMat = bicepMat = tricepMat = bicepBase = tricepBase = null;

    var file = cfg.side === "right" ? "Arm_R.gltf" : "Arm_L.gltf";
    new T.GLTFLoader().load(
      "../models/" + file,
      function (gltf) {
        if (token !== loadToken) return; // side changed while loading
        model = gltf.scene;
        scene.add(model);
        forearm = model.getObjectByName("forearm");
        upperArm = model.getObjectByName("upper_arm");
        if (!forearm) { post("error", "forearm bone not found in " + file); return; }
        restQuat = forearm.quaternion.clone();

        // The bicep/tricep meshes are unskinned roots in the file, so they
        // wouldn't follow the arm; hang them off the upper arm, keeping
        // their world placement.
        ["bicep_R", "tricep_R"].forEach(function (n) {
          var o = model.getObjectByName(n);
          if (o && upperArm) upperArm.attach(o);
        });

        model.updateMatrixWorld(true);
        skinArmMesh();

        model.traverse(function (o) {
          if (!o.isMesh || !o.material) return;
          o.frustumCulled = false; // skinned bounds are stale once bones move
          var m = o.material;
          if (m.name === "Biceps_MAT") bicepMat = m;
          else if (m.name === "Triceps_MAT") tricepMat = m;
          else skinMat = m;
        });
        if (bicepMat) bicepBase = bicepMat.color.clone();
        if (tricepMat) tricepBase = tricepMat.color.clone();

        model.updateMatrixWorld(true);
        if (!params.get("axis")) autoCalibrateFlexion();
        computeFlexFront();
        installMuscleHighlight();
        computeFraming();
        frameCamera();
        applyTier();
        ready = true;
        post("ready", { side: cfg.side });
      },
      undefined,
      function (err) {
        if (token !== loadToken) return;
        post("error", "model load failed: " + (err && err.message ? err.message : err));
      }
    );
  }

  // The arm mesh in the .gltf is one rigid piece: the armature is there but
  // nothing is skinned to it (no JOINTS/WEIGHTS), so moving the forearm bone
  // moves nothing. Give the mesh weights here instead: every vertex beyond
  // the elbow follows the forearm, every vertex before it the upper arm, with
  // a short smooth blend across the joint so the elbow bends rather than
  // hinges like a door.
  function skinArmMesh() {
    armMesh = null;
    model.traverse(function (o) {
      if (o.isMesh && !o.isSkinnedMesh && o.material &&
          o.material.name !== "Biceps_MAT" && o.material.name !== "Triceps_MAT") armMesh = o;
    });
    var hand = model.getObjectByName("hand");
    if (!armMesh || !hand || !upperArm) return;

    var elbow = forearm.getWorldPosition(new T.Vector3());
    var along = hand.getWorldPosition(new T.Vector3()).sub(elbow);
    var forearmLen = along.length();
    along.normalize();
    var blend = forearmLen * cfg.elbowBlend;

    var geo = armMesh.geometry;
    var pos = geo.getAttribute("position");
    var idx = new Uint16Array(pos.count * 4);
    var wts = new Float32Array(pos.count * 4);
    var v = new T.Vector3();
    for (var i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(armMesh.matrixWorld);
      var t = v.sub(elbow).dot(along);
      var x = Math.min(1, Math.max(0, (t + blend) / (2 * blend)));
      var w = x * x * (3 - 2 * x); // smoothstep: 0 above the elbow, 1 below
      idx[i * 4] = 0; idx[i * 4 + 1] = 1; // bones: [forearm, upper_arm]
      wts[i * 4] = w; wts[i * 4 + 1] = 1 - w;
    }
    geo.setAttribute("skinIndex", new T.Uint16BufferAttribute(idx, 4));
    geo.setAttribute("skinWeight", new T.Float32BufferAttribute(wts, 4));

    var skinned = new T.SkinnedMesh(geo, armMesh.material);
    skinned.name = armMesh.name;
    skinned.position.copy(armMesh.position);
    skinned.quaternion.copy(armMesh.quaternion);
    skinned.scale.copy(armMesh.scale);
    armMesh.parent.add(skinned);
    armMesh.parent.remove(armMesh);
    model.updateMatrixWorld(true);
    skinned.bind(new T.Skeleton([forearm, upperArm]), skinned.matrixWorld);
    armMesh = skinned;
  }

  // Direction from the elbow up the upper arm (at rest the arm is straight, so
  // it is just the opposite of elbow->hand). The upper_arm and forearm bones
  // both sit AT the elbow in this rig, so the bones can't give this axis.
  function upperArmUp() {
    var hand = model.getObjectByName("hand");
    var elbow = forearm.getWorldPosition(new T.Vector3());
    return elbow.sub(hand.getWorldPosition(new T.Vector3())).normalize();
  }

  // Which way is the FRONT of the arm (palm side)? Relaxed fingers curl toward
  // the palm, so the fingertips sit offset to that side of the forearm's line.
  // (The model's placeholder bicep spheres are not reliable for this.)
  // Returns a world-space unit vector perpendicular to the arm, or null.
  function handFront() {
    var hand = model.getObjectByName("hand");
    if (!armMesh || !hand) return null;
    var elbow = forearm.getWorldPosition(new T.Vector3());
    var wrist = hand.getWorldPosition(new T.Vector3());
    var dir = wrist.clone().sub(elbow);
    var forearmLen = dir.length();
    dir.normalize();

    var pos = armMesh.geometry.getAttribute("position");
    var v = new T.Vector3();
    var along = [];
    var maxAlong = 0;
    for (var i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(armMesh.matrixWorld).sub(elbow);
      var a = v.dot(dir);
      along.push(a);
      if (a > maxAlong) maxAlong = a;
    }
    // The fingertips: the vertices in the last stretch beyond the wrist.
    var from = forearmLen + (maxAlong - forearmLen) * 0.6;
    var sum = new T.Vector3(), n = 0;
    for (var j = 0; j < pos.count; j++) {
      if (along[j] < from) continue;
      v.fromBufferAttribute(pos, j).applyMatrix4(armMesh.matrixWorld).sub(elbow);
      sum.add(v.sub(dir.clone().multiplyScalar(v.dot(dir))));
      n++;
    }
    if (!n) return null;
    sum.divideScalar(n);
    return sum.lengthSq() > 1e-10 ? sum.normalize() : null;
  }

  // The rig's bone axes are arbitrary, so find which hinge axis/direction
  // is flexion rather than hard-coding it: flexion carries the hand toward
  // the FRONT of the upper arm, which is the side the bicep is on. Try each
  // axis and direction at 90 degrees and keep the one that moves the hand
  // furthest that way (forearm twist moves it barely at all).
  function autoCalibrateFlexion() {
    var bicep = model.getObjectByName("bicep_R");
    var hand = model.getObjectByName("hand");
    if (!bicep || !hand || !upperArm) return;
    var elbowPos = forearm.getWorldPosition(new T.Vector3());
    var axisDir = upperArmUp();
    var front = handFront();
    if (!front) {
      var b = new T.Box3().setFromObject(bicep).getCenter(new T.Vector3()).sub(elbowPos);
      front = b.sub(axisDir.clone().multiplyScalar(b.dot(axisDir))).normalize();
    }

    var rest = hand.getWorldPosition(new T.Vector3());
    var best = { score: -Infinity, axis: cfg.axis, sign: cfg.sign };
    var q = restQuat.clone();
    ["x", "y", "z"].forEach(function (axis) {
      [1, -1].forEach(function (sign) {
        var a = new T.Vector3(axis === "x" ? 1 : 0, axis === "y" ? 1 : 0, axis === "z" ? 1 : 0);
        forearm.quaternion.copy(restQuat).multiply(q.setFromAxisAngle(a, sign * Math.PI / 2));
        forearm.updateMatrixWorld(true);
        var score = hand.getWorldPosition(new T.Vector3()).sub(rest).dot(front);
        if (score > best.score) best = { score: score, axis: axis, sign: sign };
      });
    });
    forearm.quaternion.copy(restQuat);
    forearm.updateMatrixWorld(true);
    cfg.axis = best.axis;
    cfg.sign = best.sign;
    // Look straight down the hinge so the bend is seen in profile.
    var hinge = new T.Vector3(best.axis === "x" ? 1 : 0, best.axis === "y" ? 1 : 0, best.axis === "z" ? 1 : 0)
      .transformDirection(forearm.matrixWorld);
    if (params.get("az") === null) cfg.azimuthDeg = Math.atan2(hinge.x, hinge.z) * 180 / Math.PI;
    post("calibrated", { axis: best.axis, sign: best.sign });
  }

  // ---- muscle activation shown on the arm itself ---------------------------
  // The file's bicep/tricep meshes sit inside the arm surface and can't be seen,
  // so activation is painted onto the arm: each vertex gets a weight for "is
  // this the biceps / the triceps region", and the shader tints by effort and
  // swells the region slightly as it contracts.
  var muscleUniforms = {
    uBicep: { value: 0 }, uTricep: { value: 0 }, uTricepOn: { value: 0 },
    uBulge: { value: cfg.bulge },
    uColorB: { value: new T.Color(cfg.muscleStops[0][1]) },
    uColorT: { value: new T.Color(cfg.muscleStops[0][1]) },
  };
  var flexFront = null; // world direction the forearm swings toward when the elbow flexes
  var tricepSeen = false;

  // Anatomy: the elbow flexes toward the front of the arm, and the biceps is on
  // that side. So "front" is whichever way the hand moves when flexed (which
  // autoCalibrateFlexion chose to match the palm side).
  function computeFlexFront() {
    var hand = model.getObjectByName("hand");
    if (!hand || !upperArm) return;
    var axisDir = upperArmUp();
    var rest = hand.getWorldPosition(new T.Vector3());
    var a = new T.Vector3(cfg.axis === "x" ? 1 : 0, cfg.axis === "y" ? 1 : 0, cfg.axis === "z" ? 1 : 0);
    var q = restQuat.clone();
    forearm.quaternion.copy(restQuat).multiply(q.setFromAxisAngle(a, cfg.sign * Math.PI / 2));
    forearm.updateMatrixWorld(true);
    var d = hand.getWorldPosition(new T.Vector3()).sub(rest);
    forearm.quaternion.copy(restQuat);
    forearm.updateMatrixWorld(true);
    d.sub(axisDir.clone().multiplyScalar(d.dot(axisDir)));
    if (d.lengthSq() > 1e-8) flexFront = d.normalize();
  }

  function smooth(e0, e1, x) {
    var t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
    return t * t * (3 - 2 * t);
  }

  function installMuscleHighlight() {
    ["bicep_R", "tricep_R"].forEach(function (n) {
      var o = model.getObjectByName(n);
      if (o) o.visible = false; // the hidden placeholder meshes
    });
    if (!armMesh || !flexFront || !upperArm) return;

    var elbow = forearm.getWorldPosition(new T.Vector3());
    var axisDir = upperArmUp();

    var geo = armMesh.geometry;
    var pos = geo.getAttribute("position");
    var weights = new Float32Array(pos.count * 2);
    var v = new T.Vector3();

    // Upper-arm length: how far the mesh extends up from the elbow.
    var len = 0;
    for (var j = 0; j < pos.count; j++) {
      v.fromBufferAttribute(pos, j).applyMatrix4(armMesh.matrixWorld).sub(elbow);
      len = Math.max(len, v.dot(axisDir));
    }
    if (len < 1e-6) return;

    for (var i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(armMesh.matrixWorld).sub(elbow);
      var along = v.dot(axisDir);
      var t = along / len; // 0 at the elbow, 1 at the top of the shoulder
      var radial = v.sub(axisDir.clone().multiplyScalar(along));
      var rl = radial.length();
      var facing = rl > 1e-6 ? radial.dot(flexFront) / rl : 0; // +1 front, -1 back
      var belly = smooth(0.08, 0.22, t) * (1 - smooth(0.7, 0.9, t)); // the muscle belly, between elbow and shoulder
      weights[i * 2] = belly * smooth(0.0, 0.55, facing); // biceps (front)
      weights[i * 2 + 1] = belly * smooth(0.0, 0.55, -facing); // triceps (back)
    }
    geo.setAttribute("aMuscle", new T.Float32BufferAttribute(weights, 2));

    var mat = armMesh.material;
    mat.onBeforeCompile = function (shader) {
      Object.assign(shader.uniforms, muscleUniforms);
      shader.vertexShader = shader.vertexShader
        .replace("#include <common>", "#include <common>\nattribute vec2 aMuscle;\nuniform float uBicep;\nuniform float uTricep;\nuniform float uBulge;\nvarying vec2 vMuscle;")
        .replace("#include <begin_vertex>", "#include <begin_vertex>\nvMuscle = aMuscle;\ntransformed += normalize(objectNormal) * (aMuscle.x * uBicep + aMuscle.y * uTricep) * uBulge;");
      shader.fragmentShader = shader.fragmentShader
        .replace("#include <common>", "#include <common>\nvarying vec2 vMuscle;\nuniform float uBicep;\nuniform float uTricep;\nuniform float uTricepOn;\nuniform vec3 uColorB;\nuniform vec3 uColorT;")
        .replace("#include <color_fragment>", "#include <color_fragment>\nfloat mwB = clamp(vMuscle.x * (0.4 + 0.6 * uBicep), 0.0, 1.0);\nfloat mwT = clamp(vMuscle.y * uTricepOn * (0.4 + 0.6 * uTricep), 0.0, 1.0);\ndiffuseColor.rgb = mix(diffuseColor.rgb, uColorB, mwB * 0.9);\ndiffuseColor.rgb = mix(diffuseColor.rgb, uColorT, mwT * 0.9);")
        // A glow on top, so the colour reads whatever the lighting does to the skin.
        .replace("#include <emissivemap_fragment>", "#include <emissivemap_fragment>\ntotalEmissiveRadiance += uColorB * mwB * 0.5 + uColorT * mwT * 0.5;");
    };
    mat.needsUpdate = true;
  }

  // Fit the whole arm in view once; the camera orbits around its centre.
  function computeFraming() {
    var box = new T.Box3().setFromObject(armMesh || model);
    var size = box.getSize(new T.Vector3());
    framing = {
      centre: box.getCenter(new T.Vector3()),
      radius: Math.max(size.x, size.y, size.z) * 0.5,
    };
  }

  function frameCamera() {
    if (!framing) return;
    var fov = camera.fov * Math.PI / 180;
    var dist = framing.radius / Math.sin(fov / 2) * 1.7;
    if (camera.aspect < 1) dist /= camera.aspect; // portrait: width is the limit
    var az = cfg.azimuthDeg * Math.PI / 180;
    camera.position.set(
      framing.centre.x + Math.sin(az) * dist,
      framing.centre.y,
      framing.centre.z + Math.cos(az) * dist
    );
    camera.lookAt(framing.centre);
    camera.updateMatrixWorld(true);
  }

  var flexAxis = new T.Vector3();
  var flexQuat = null;
  function applyPose() {
    if (!forearm || !restQuat) return;
    flexAxis.set(cfg.axis === "x" ? 1 : 0, cfg.axis === "y" ? 1 : 0, cfg.axis === "z" ? 1 : 0);
    var rad = T.MathUtils.degToRad(cfg.sign * (state.elbowNow + cfg.offsetDeg));
    if (!flexQuat) flexQuat = restQuat.clone();
    flexQuat.setFromAxisAngle(flexAxis, rad);
    // rest * flex: rotate about the bone's own local axis, from its rest pose.
    forearm.quaternion.copy(restQuat).multiply(flexQuat);
  }

  function applyTier() {
    if (!skinMat || !skinMat.emissive) return;
    skinMat.emissive.set(cfg.tierColors[state.tier] || cfg.tierColors.normal);
    skinMat.emissiveIntensity = state.tier === "normal" ? 0.12 : 0.35;
  }

  // Colour for an effort level, interpolated along cfg.muscleStops.
  var rampA = new T.Color(), rampB = new T.Color();
  function muscleColor(pct, out) {
    var st = cfg.muscleStops;
    if (pct <= st[0][0]) return out.set(st[0][1]);
    for (var i = 1; i < st.length; i++) {
      if (pct <= st[i][0]) {
        var t = (pct - st[i - 1][0]) / (st[i][0] - st[i - 1][0]);
        return out.copy(rampA.set(st[i - 1][1])).lerp(rampB.set(st[i][1]), t);
      }
    }
    return out.set(st[st.length - 1][1]);
  }

  function applyEmg() {
    muscleUniforms.uBicep.value = state.bicepNow / 100;
    muscleUniforms.uTricep.value = tricepSeen ? state.tricepNow / 100 : 0;
    muscleUniforms.uTricepOn.value = tricepSeen ? 1 : 0;
    muscleColor(state.bicepNow, muscleUniforms.uColorB.value);
    muscleColor(state.tricepNow, muscleUniforms.uColorT.value);
  }

  function step(dtSec) {
    // Frame-rate independent: same feel at 30 and 60 fps.
    var k = 1 - Math.pow(1 - cfg.easing, dtSec * 60);
    state.elbowNow += (state.elbowTarget - state.elbowNow) * k;
    state.bicepNow += (state.bicepTarget - state.bicepNow) * k;
    state.tricepNow += (state.tricepTarget - state.tricepNow) * k;
  }

  function frame() {
    rafId = requestAnimationFrame(frame);
    step(Math.min(clock.getDelta(), 0.1));
    applyPose();
    applyEmg();
    renderer.render(scene, camera);
    if (devReadout) devReadout();
  }
  function startLoop() { if (!rafId) { clock.getDelta(); rafId = requestAnimationFrame(frame); } }
  function stopLoop() { if (rafId) { cancelAnimationFrame(rafId); rafId = 0; } }

  function clamp(v, lo, hi) {
    v = Number(v);
    return isFinite(v) ? Math.min(hi, Math.max(lo, v)) : lo;
  }

  // --- the API Flutter calls ------------------------------------------------
  window.twin = {
    setElbow: function (deg) { state.elbowTarget = clamp(deg, -30, 200); },
    setTier: function (t) {
      state.tier = cfg.tierColors[t] ? t : "normal";
      applyTier();
    },
    setEmg: function (bicepPct, tricepPct) {
      state.bicepTarget = clamp(bicepPct, 0, 100);
      state.tricepTarget = clamp(tricepPct, 0, 100);
      if (state.tricepTarget > 0) tricepSeen = true; // the band has no triceps channel yet
    },
    setSide: function (side) {
      side = side === "right" ? "right" : "left";
      if (side === cfg.side && model) return;
      cfg.side = side;
      loadModel();
    },
    // Partial config: axis, sign, offsetDeg, azimuthDeg, tierColors, emgHot, easing.
    configure: function (o) {
      Object.keys(o || {}).forEach(function (k) {
        if (k === "tierColors") Object.assign(cfg.tierColors, o.tierColors);
        else if (k in cfg && k !== "side") cfg[k] = o[k];
      });
      frameCamera();
      applyTier();
    },
    pause: function () { paused = true; stopLoop(); },
    resume: function () { paused = false; if (!document.hidden) startLoop(); },
    isReady: function () { return ready; },
    _debug: function () {
      return {
        cfg: cfg, state: state, ready: ready,
        framing: framing && { centre: framing.centre.toArray(), radius: framing.radius },
        camera: camera.position.toArray(),
        elbow: forearm && forearm.getWorldPosition(new T.Vector3()).toArray(),
      };
    },
  };

  // --- dev panel (?dev=1): find the elbow axis/sign in a browser ------------
  function buildDevPanel() {
    var p = document.createElement("div");
    p.style.cssText = "position:fixed;left:8px;top:8px;padding:8px 10px;background:rgba(255,255,255,.92);font:12px sans-serif;border-radius:8px;z-index:9;width:220px";
    p.innerHTML =
      '<div>elbow <b id="dv">0</b>&deg; <input id="d" type="range" min="-30" max="170" value="0" style="width:100%"></div>' +
      '<div>axis <select id="a"><option>x</option><option>y</option><option>z</option></select> ' +
      'sign <select id="s"><option value="1">+</option><option value="-1">-</option></select></div>' +
      '<div>view az <input id="az" type="range" min="0" max="360" value="' + cfg.azimuthDeg + '" style="width:100%"></div>' +
      '<div>side <select id="side"><option>left</option><option>right</option></select> ' +
      'tier <select id="t"><option value="normal">normal</option><option value="needsCorrection">correct</option><option value="unsafe">unsafe</option></select></div>' +
      '<div>emg <input id="e" type="range" min="0" max="100" value="0" style="width:100%"></div>' +
      '<div id="out" style="color:#555;margin-top:4px"></div>';
    document.body.appendChild(p);
    var $ = function (id) { return p.querySelector("#" + id); };
    $("a").value = cfg.axis;
    $("s").value = String(cfg.sign);
    $("side").value = cfg.side;
    $("d").oninput = function () { window.twin.setElbow(this.value); $("dv").textContent = this.value; };
    $("a").onchange = function () { cfg.axis = this.value; };
    $("s").onchange = function () { cfg.sign = Number(this.value); };
    $("az").oninput = function () { cfg.azimuthDeg = Number(this.value); frameCamera(); };
    $("side").onchange = function () { window.twin.setSide(this.value); };
    $("t").onchange = function () { window.twin.setTier(this.value); };
    $("e").oninput = function () { window.twin.setEmg(this.value, this.value / 2); };
    devReadout = function () {
      if (ready && document.activeElement !== $("a") && document.activeElement !== $("s")) {
        $("a").value = cfg.axis;
        $("s").value = String(cfg.sign);
      }
      $("out").textContent = ready ? "axis " + cfg.axis + (cfg.sign > 0 ? "+" : "-") + " az " + Math.round(cfg.azimuthDeg) + " (auto unless ?axis= given)" : "loading...";
    };
  }

  init();
})();
