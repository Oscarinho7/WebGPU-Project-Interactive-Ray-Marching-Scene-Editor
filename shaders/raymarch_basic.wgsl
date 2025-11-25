// Basic Ray Marching with Simple Primitives
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let uv = (fragCoord.xy - uniforms.resolution * 0.5) / min(uniforms.resolution.x, uniforms.resolution.y);

  // Camera Coords
  let cam_pos = uniforms.camera_pos;
  let cam_target = cam_pos + uniforms.camera_front;

  // Camera Matrix
  let cam_forward = normalize(uniforms.camera_front);
  let cam_right = normalize(cross(cam_forward, vec3<f32>(0.0, 1.0, 0.0)));
  let cam_up = cross(cam_right, cam_forward); // Re-orthogonalized up

  // Ray Direction
  // 1.5 is the "focal length" or distance to the projection plane
  let focal_length = 1.5;
  let rd = normalize(cam_right * uv.x - cam_up * uv.y + cam_forward * focal_length);

  // Ray march
  let result = ray_march(cam_pos, rd);

  // Sky gradient
  var final_color = mix(MAT_SKY_COLOR, MAT_SKY_COLOR * 0.9, uv.y * 0.5 + 0.5);

  if result.x < MAX_DIST {
    // Hit something - calculate lighting
    let hit_pos = cam_pos + rd * result.x;
    let normal = get_normal(hit_pos);

    // Diffuse Lighting
    let light_pos = vec3<f32>(2.0, 5.0, -1.0);
    let light_dir = normalize(light_pos - hit_pos);
    let diffuse = max(dot(normal, light_dir), 0.0);

    // Shadow Casting
    let shadow_origin = hit_pos + normal * 0.01;
    let shadow_result = ray_march(shadow_origin, light_dir);
    let shadow = select(0.3, 1.0, shadow_result.x > length(light_pos - shadow_origin));

    // Phong Shading
    let ambient = 0.2;
    var albedo = get_material_color(result.y, hit_pos);
    let phong = albedo * (ambient + diffuse * shadow * 0.8);

    // Exponential Fog
    let fog = exp(-result.x * 0.002); // Reduced fog (was 0.02)
    final_color = mix(MAT_SKY_COLOR, phong, fog);
  }

  // Transparent Grid Floor
  // Plane equation: y = -0.5
  // Ray: ro + rd * t
  // ro.y + rd.y * t = -0.5  =>  t = (-0.5 - ro.y) / rd.y
  if abs(rd.y) > 0.001 {
      let t_plane = (-0.5 - cam_pos.y) / rd.y;
      if t_plane > 0.0 && (result.x >= MAX_DIST || t_plane < result.x) {
          let pos = cam_pos + rd * t_plane;
          // Grid pattern
          let grid_size = 1.0;
          let line_width = 0.02;
          let g = step(1.0 - line_width, fract(pos.x)) + step(1.0 - line_width, fract(pos.z));
          let grid_color = vec3<f32>(0.8, 0.8, 0.8); // Brighter grid lines
          let grid_alpha = min(g, 0.8); // More intense (was 0.3)
          
          // Fade grid with distance
          let fade = exp(-t_plane * 0.05);
          
          final_color = mix(final_color, grid_color, grid_alpha * fade);
      }
  }

  return vec4<f32>(gamma_correct(final_color), 1.0);
}

// Gamma Correction
fn gamma_correct(color: vec3<f32>) -> vec3<f32> {
  return pow(color, vec3<f32>(1.0 / 2.2));
}

// Constants
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;
const MAX_STEPS: i32 = 256;

// Material Types
const MAT_PLANE: f32 = 0.0;
const MAT_SPHERE_BASE: f32 = 10.0;
const MAT_BOX_BASE: f32 = 20.0;
const MAT_TORUS: f32 = 3.0;
const MAT_AXIS_X: f32 = 4.0;
const MAT_AXIS_Y: f32 = 5.0;
const MAT_AXIS_Z: f32 = 6.0;

// Material Colors
const MAT_SKY_COLOR: vec3<f32> = vec3<f32>(0.15, 0.15, 0.15); // Professional Grey
const MAT_TORUS_COLOR: vec3<f32> = vec3<f32>(0.3, 0.3, 1.0);

fn get_material_color(mat_id: f32, p: vec3<f32>) -> vec3<f32> {
  if mat_id == MAT_PLANE {
    let checker = floor(p.x) + floor(p.z);
    let col1 = vec3<f32>(0.9, 0.9, 0.9);
    let col2 = vec3<f32>(0.2, 0.2, 0.2);
    return select(col2, col1, i32(checker) % 2 == 0);
  } else if mat_id >= MAT_SPHERE_BASE && mat_id < MAT_SPHERE_BASE + 4.0 {
    let idx = u32(mat_id - MAT_SPHERE_BASE);
    return uniforms.scene.spheres[idx].color;
  } else if mat_id >= MAT_BOX_BASE && mat_id < MAT_BOX_BASE + 4.0 {
    let idx = u32(mat_id - MAT_BOX_BASE);
    return uniforms.scene.boxes[idx].color;
  } else if mat_id == MAT_TORUS {
    return MAT_TORUS_COLOR;
  } else if mat_id == MAT_AXIS_X {
    return vec3<f32>(1.0, 0.0, 0.0); // Red X
  } else if mat_id == MAT_AXIS_Y {
    return vec3<f32>(0.0, 1.0, 0.0); // Green Y
  } else if mat_id == MAT_AXIS_Z {
    return vec3<f32>(0.0, 0.0, 1.0); // Blue Z
  }
  return vec3<f32>(0.5, 0.5, 0.5);
}

// SDF Primitives
fn sd_sphere(p: vec3<f32>, r: f32) -> f32 {
  return length(p) - r;
}

fn sd_box(p: vec3<f32>, b: vec3<f32>) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn sd_torus(p: vec3<f32>, t: vec2<f32>) -> f32 {
  let q = vec2<f32>(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

fn sd_plane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
  return dot(p, n) + h;
}

// SDF Operations
fn op_union(d1: f32, d2: f32) -> f32 {
  return min(d1, d2);
}

fn op_subtract(d1: f32, d2: f32) -> f32 {
  return max(-d1, d2);
}

fn op_intersect(d1: f32, d2: f32) -> f32 {
  return max(d1, d2);
}

fn op_smooth_union(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

fn sd_cone(p: vec3<f32>, c: vec2<f32>, h: f32) -> f32 {
  let q = length(p.xz);
  return max(dot(c.xy, vec2<f32>(q, p.y)), -h - p.y);
}

// Scene description - returns (distance, material_id)
fn get_dist(p: vec3<f32>) -> vec2<f32> {
  let time = uniforms.time;
  var res = vec2<f32>(MAX_DIST, -1.0);

  // Loop through spheres
  for (var i: u32 = 0; i < uniforms.scene.num_spheres; i++) {
      let sphere = uniforms.scene.spheres[i];
      let d = sd_sphere(p - sphere.pos, sphere.r);
      if d < res.x {
          res = vec2<f32>(d, MAT_SPHERE_BASE + f32(i));
      }
  }

  // Loop through boxes
  for (var i: u32 = 0; i < uniforms.scene.num_boxes; i++) {
      let box = uniforms.scene.boxes[i];
      let d = sd_box(p - box.pos, box.size);
      if d < res.x {
          res = vec2<f32>(d, MAT_BOX_BASE + f32(i));
      }
  }

  // Torus removed
  // let torus_dist = sd_torus(p - vec3<f32>(-1.5, 0.5, 1.0), vec2<f32>(0.4, 0.15));
  // if torus_dist < res.x {
  //   res = vec2<f32>(torus_dist, MAT_TORUS);
  // }

  // Coordinate Axes
  let axis_thickness = 0.01;
  let axis_len = 1.0;
  let cone_h = 0.2;
  let cone_r = 0.05;
  // Cone angle calc: tan(theta) = r/h. c = (cos(theta), sin(theta))
  let cone_c = vec2<f32>(0.970, 0.242);

  // X Axis (Red)
  // Box
  let d_x_box = sd_box(p - vec3<f32>(axis_len * 0.5, 0.0, 0.0), vec3<f32>(axis_len * 0.5, axis_thickness, axis_thickness));
  // Cone: Rotate +90 deg around Z to point +X
  // x' = -y, y' = x
  // p_cone_x_rot = (-p.y, p.x, p.z)
  let d_x_cone = sd_cone(vec3<f32>(-p.y, p.x - axis_len, p.z), cone_c, cone_h);
  let d_x = min(d_x_box, d_x_cone);
  if d_x < res.x { res = vec2<f32>(d_x, MAT_AXIS_X); }

  // Y Axis (Green)
  // Box
  let d_y_box = sd_box(p - vec3<f32>(0.0, axis_len * 0.5, 0.0), vec3<f32>(axis_thickness, axis_len * 0.5, axis_thickness));
  // Cone: Points +Y (default)
  let d_y_cone = sd_cone(p - vec3<f32>(0.0, axis_len, 0.0), cone_c, cone_h);
  let d_y = min(d_y_box, d_y_cone);
  if d_y < res.x { res = vec2<f32>(d_y, MAT_AXIS_Y); }

  // Z Axis (Blue)
  // Box
  let d_z_box = sd_box(p - vec3<f32>(0.0, 0.0, axis_len * 0.5), vec3<f32>(axis_thickness, axis_thickness, axis_len * 0.5));
  // Cone: Rotate 90 deg around X to point +Z
  // y' = z, z' = -y
  // p_cone_z_rot = (p.x, p.z, -p.y)
  // Wait, previous was: vec3<f32>(p.x, p.z - axis_len, -p.y)
  // Let's stick to that if it worked (it pointed +Z).
  let d_z_cone_rot = sd_cone(vec3<f32>(p.x, p.z - axis_len, -p.y), cone_c, cone_h);
  let d_z = min(d_z_box, d_z_cone_rot);
  if d_z < res.x { res = vec2<f32>(d_z, MAT_AXIS_Z); }

  return res;
}

// Ray marching function - returns (distance, material_id)
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> vec2<f32> {
  var d = 0.0;
  var mat_id = -1.0;

  for (var i = 0; i < MAX_STEPS; i++) {
    let p = ro + rd * d;
    let dist_mat = get_dist(p);
    d += dist_mat.x;
    mat_id = dist_mat.y;

    if dist_mat.x < SURF_DIST || d > MAX_DIST {
      break;
    }
  }

  return vec2<f32>(d, mat_id);
}

// Calculate normal using gradient
fn get_normal(p: vec3<f32>) -> vec3<f32> {
  let e = vec2<f32>(0.001, 0.0);
  let n = vec3<f32>(
    get_dist(p + e.xyy).x - get_dist(p - e.xyy).x,
    get_dist(p + e.yxy).x - get_dist(p - e.yxy).x,
    get_dist(p + e.yyx).x - get_dist(p - e.yyx).x
  );
  return normalize(n);
}
