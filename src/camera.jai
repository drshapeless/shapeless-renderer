Camera :: struct {
    pos   : Vector3;
    front : Vector3;
    up    : Vector3;

    fov: float;
    aspect_ratio: float;
    near_plane: float;
    far_plane: float;

    roll: float;
}

init_camera :: (camera: *Camera, aspect_ratio: float) {
    camera.pos = .{0, 0, -4};
    camera.front = .{0, 0, 0};
    camera.up = .{0, -1, 0};

    camera.fov = to_radian(45.0);
    camera.aspect_ratio = aspect_ratio;
    camera.near_plane = 0.1;
    camera.far_plane = 100.0;
}

camera_view :: (camera: *Camera) -> Matrix4 {
    w := normalize(camera.front);
    u := normalize(cross(w, camera.up));
    v := cross(w, u);

    view := Matrix4_Identity;
    view._11 = u.x;
    view._12 = u.y;
    view._13 = u.z;
    view._21 = v.x;
    view._22 = v.y;
    view._23 = v.z;
    view._31 = w.x;
    view._32 = w.y;
    view._33 = w.z;
    view._14 = -dot(u, camera.pos);
    view._24 = -dot(v, camera.pos);
    view._34 = -dot(w, camera.pos);

    return view;
}

camera_projection :: (using camera: *Camera) -> Matrix4 {
    tan_half_fov := tan(fov / 2);
    projection: Matrix4;
    projection._11 = 1.0 / (aspect_ratio * tan_half_fov);
    projection._22 = 1.0 / tan_half_fov;
    projection._33 = far_plane / (far_plane - near_plane);
    projection._34 = -(far_plane * near_plane) / (far_plane - near_plane);
    projection._43 = 1.0;

    return projection;
}

to_radian :: (angle: float) -> float {
    return angle / 180.0 * PI;
}

#import "Math";
#import "Basic";
