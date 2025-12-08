// Basic Ray Marching with Simple Primitives
@fragment
fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let uv = (fragCoord.xy - uniforms.resolution * 0.5) / min(uniforms.resolution.x, uniforms.resolution.y);

  // Camera Coords
  let cam_pos = uniforms.camera_pos;
  
  // Camera Matrix (Restored)
  let cam_forward = normalize(uniforms.camera_front);
  let cam_right = normalize(cross(cam_forward, vec3<f32>(0.0, 1.0, 0.0)));
  let cam_up = cross(cam_right, cam_forward); // Re-orthogonalized up

  // Ray Direction (Restored)
  let focal_length = 1.5;
  let rd = normalize(cam_right * uv.x - cam_up * uv.y + cam_forward * focal_length);

  // Ray march
  let result = ray_march(cam_pos, rd);

  // Sky gradient
  var final_color = mix(MAT_SKY_COLOR, MAT_SKY_COLOR * 0.8, uv.y * 0.5 + 0.5);

  if result.x < MAX_DIST {
    // Hit something - calculate lighting
    let hit_pos = cam_pos + rd * result.x;
    let normal = get_normal(hit_pos);

    // Lighting (New)
    let light_pos = uniforms.light_pos;
    let l = normalize(light_pos - hit_pos);
    let diff = max(dot(normal, l), 0.0);

    // Soft Shadows (New)
    let shadow = soft_shadow(hit_pos + normal * 0.01, l, 0.02, length(light_pos - hit_pos), 8.0);

    // Material Color
    var obj_color = get_material_color(result.y, hit_pos);
    
    // Combine
    let ambient = vec3<f32>(0.2);
    let diffuse = obj_color * diff * uniforms.light_intensity * shadow;
    final_color = ambient * obj_color + diffuse;
    
    // Exponential Fog
    final_color = mix(final_color, MAT_SKY_COLOR, 1.0 - exp(-result.x * 0.002));
  }

  // Transparent Grid Floor (Restored)
  // Plane equation: y = -0.5
  if abs(rd.y) > 0.001 {
      let t_plane = (-0.5 - cam_pos.y) / rd.y;
      if t_plane > 0.0 && (result.x >= MAX_DIST || t_plane < result.x) {
          let pos = cam_pos + rd * t_plane;
          // Grid pattern
          let line_width = 0.02;
          let g = step(1.0 - line_width, fract(pos.x)) + step(1.0 - line_width, fract(pos.z));
          let grid_color = vec3<f32>(0.8, 0.8, 0.8); // Brighter grid lines
          let grid_alpha = min(g, 0.8); // More intense
          
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
const MAT_TORUS_BASE: f32 = 30.0;
const MAT_PYRAMID_BASE: f32 = 40.0;

// Material Colors
const MAT_SKY_COLOR: vec3<f32> = vec3<f32>(0.15, 0.15, 0.15); // Darker background

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
  } else if mat_id >= MAT_TORUS_BASE && mat_id < MAT_TORUS_BASE + 4.0 {
    let idx = u32(mat_id - MAT_TORUS_BASE);
    return uniforms.scene.toruses[idx].color;
  } else if mat_id >= MAT_PYRAMID_BASE && mat_id < MAT_PYRAMID_BASE + 4.0 {
    let idx = u32(mat_id - MAT_PYRAMID_BASE);
    return uniforms.scene.pyramids[idx].color;
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

fn sd_pyramid(p: vec3<f32>, h: f32) -> f32 {
  var p_mod = p;
  let m2 = h * h + 0.25;
  
  // Symmetry
  p_mod.x = abs(p_mod.x);
  p_mod.z = abs(p_mod.z);
  if (p_mod.z > p_mod.x) { 
      let tmp = p_mod.z; p_mod.z = p_mod.x; p_mod.x = tmp; 
  }
  p_mod.x = p_mod.x - 0.5;
  p_mod.z = p_mod.z - 0.5;
  
  let q = vec3<f32>(p_mod.z, h * p_mod.y - 0.5 * p_mod.x, h * p_mod.x + 0.5 * p_mod.y);
  
  let s = max(-q.x, 0.0);
  let t = clamp((q.y - 0.5 * p_mod.z) / (m2 + 0.25), 0.0, 1.0);
  
  let a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
  let b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);
  
  let d2 = select(min(a, b), 0.0, min(q.y, -q.x * m2 - q.y * 0.5) > 0.0);
  
  return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p_mod.y));
}

fn sd_plane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
  return dot(p, n) + h;
}



// SDF Operations
fn op_smooth_union(d1: f32, d2: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Soft Shadow
fn soft_shadow(ro: vec3<f32>, rd: vec3<f32>, mint: f32, maxt: f32, k: f32) -> f32 {
    var res = 1.0;
    var t = mint;
    for (var i = 0; i < 64 && t < maxt; i++) {
        let h = get_dist(ro + rd * t).x;
        if (h < 0.001) { return 0.0; }
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Scene description - returns (distance, material_id)
fn get_dist(p: vec3<f32>) -> vec2<f32> {
  var smooth_d = MAX_DIST;
  var hard_d = MAX_DIST;
  var mat_id = -1.0;
  let k = uniforms.smooth_blend; // Smooth blend factor from uniform

  // Loop through spheres
  for (var i: u32 = 0; i < uniforms.scene.num_spheres; i++) {
      let sphere = uniforms.scene.spheres[i];
      let d = sd_sphere(p - sphere.pos, sphere.r);
      smooth_d = op_smooth_union(smooth_d, d, k);
      if d < hard_d {
          hard_d = d;
          mat_id = MAT_SPHERE_BASE + f32(i);
      }
  }

  // Loop through boxes
  for (var i: u32 = 0; i < uniforms.scene.num_boxes; i++) {
      let box = uniforms.scene.boxes[i];
      let d = sd_box(p - box.pos, box.size);
      smooth_d = op_smooth_union(smooth_d, d, k);
      if d < hard_d {
          hard_d = d;
          mat_id = MAT_BOX_BASE + f32(i);
      }
  }

  // Loop through toruses
  for (var i: u32 = 0; i < uniforms.scene.num_toruses; i++) {
      let torus = uniforms.scene.toruses[i];
      let d = sd_torus(p - torus.pos, torus.t);
      smooth_d = op_smooth_union(smooth_d, d, k);
      if d < hard_d {
          hard_d = d;
          mat_id = MAT_TORUS_BASE + f32(i);
      }
  }

  // Loop through pyramids
  for (var i: u32 = 0; i < uniforms.scene.num_pyramids; i++) {
      let pyr = uniforms.scene.pyramids[i];
      let d = sd_pyramid(p - pyr.pos, pyr.h);
      smooth_d = op_smooth_union(smooth_d, d, k);
      if d < hard_d {
          hard_d = d;
          mat_id = MAT_PYRAMID_BASE + f32(i);
      }
  }

  return vec2<f32>(smooth_d, mat_id);
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
