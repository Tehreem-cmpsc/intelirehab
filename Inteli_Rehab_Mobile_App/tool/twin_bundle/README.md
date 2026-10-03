# twin_bundle

Build-time tool that produces `assets/twin/three_bundle.js` (Three.js +
GLTFLoader, minified, exposed as `window.ThreeBundle`). The generated file
is committed, so building the app never needs Node.

Regenerate after changing `entry.js` or the Three.js version:

    cd tool/twin_bundle
    npm install
    npm run build
