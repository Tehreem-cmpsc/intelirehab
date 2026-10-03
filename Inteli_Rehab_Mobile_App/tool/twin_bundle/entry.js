// Exposes only what the twin page needs as window.ThreeBundle, so the page
// can be a plain classic <script> (no import maps / module fetches, which
// don't resolve reliably from a WebView's local asset origin).
import {
  WebGLRenderer, Scene, PerspectiveCamera, HemisphereLight, DirectionalLight,
  Color, Clock, MathUtils, Box3, Vector3,
  SkinnedMesh, Skeleton, Uint16BufferAttribute, Float32BufferAttribute,
} from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

window.ThreeBundle = {
  WebGLRenderer, Scene, PerspectiveCamera, HemisphereLight, DirectionalLight,
  Color, Clock, MathUtils, Box3, Vector3, GLTFLoader,
  SkinnedMesh, Skeleton, Uint16BufferAttribute, Float32BufferAttribute,
};
