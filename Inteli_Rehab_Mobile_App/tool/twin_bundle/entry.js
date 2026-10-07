// Exposes only what the twin page needs as window.ThreeBundle, so the page
// can be a plain classic <script> (no import maps / module fetches, which
// don't resolve reliably from a WebView's local asset origin).
import {
  WebGLRenderer, Scene, PerspectiveCamera, HemisphereLight, DirectionalLight,
  Color, Clock, MathUtils, Box3, Vector3,
  SkinnedMesh, Skeleton, Uint16BufferAttribute, Float32BufferAttribute,
  PMREMGenerator, ACESFilmicToneMapping, SRGBColorSpace,
} from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
// Soft studio-style lighting (image-based), so skin is lit from all around like Blender's viewport.
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

window.ThreeBundle = {
  WebGLRenderer, Scene, PerspectiveCamera, HemisphereLight, DirectionalLight,
  Color, Clock, MathUtils, Box3, Vector3, GLTFLoader,
  SkinnedMesh, Skeleton, Uint16BufferAttribute, Float32BufferAttribute,
  PMREMGenerator, ACESFilmicToneMapping, SRGBColorSpace, RoomEnvironment,
};
