/*
 * Copyright (C) 2017-2020 Trent Houliston <trent@houliston.me>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * Projects visual mesh points to a Fisheye camera with equidistant projection
 *
 * @param points      VisualMesh unit vectors as 4d vectors [x, y, z, 0]
 * @param indices     map from local indices to global indices
 * @param Rco         rotation from the observation space to camera space
 *                    note that while this is a 4x4, that is for memory alignment, no translation should exist
 *                    (or would be applied anyway)
 * @param f           the focal length of the lens measured in pixels
 * @param centre      the offset from the centre of the lens axis to the centre of the image in pixels
 * @param k           the inverse distortion coefficients to apply the distortion to the image
 * @param dimensions  the dimensions of the input image
 * @param out         the output image coordinates
 */
kernel void project_equidistant(global const Scalar4* points,
                                global int* indices,
                                const Scalar16 Rco,
                                const Scalar f,
                                const Scalar2 centre,
                                const Scalar4 k,
                                const int2 dimensions,
                                global Scalar2* out) {

    const int index = get_global_id(0);

    // Get our real index
    const int id = indices[index];

    // Get our LUT point
    Scalar4 ray = points[id];

    // Rotate our ray by our matrix to put it into camera space
    ray = (Scalar4)(dot(Rco.s0123, ray), dot(Rco.s4567, ray), dot(Rco.s89ab, ray), 0);

    // Calculate some intermediates
    const Scalar theta      = acos(ray.x);
    const Scalar rsin_theta = rsqrt((Scalar)(1.0) - ray.x * ray.x);
    const Scalar r_u        = f * theta;
    const Scalar r_d        = r_u
                       * (1.0                                                                  //
                          + k.x * (r_u * r_u)                                                  //
                          + k.y * ((r_u * r_u) * (r_u * r_u))                                  //
                          + k.z * (((r_u * r_u) * (r_u * r_u)) * (r_u * r_u))                  //
                          + k.w * (((r_u * r_u) * (r_u * r_u)) * ((r_u * r_u) * (r_u * r_u)))  //
                       );

    // Work out our pixel coordinates as a 0 centred image with x to the left and y up (screen space)
    Scalar2 screen = (Scalar2)(r_d * ray.y * rsin_theta, r_d * ray.z * rsin_theta);
    screen         = ray.x >= 1 ? (Scalar2)(0.0, 0.0) : screen;  // When the pixel is at (1,0,0) lots of NaNs show up

    // Apply our offset to move into image space (0 at top left, x to the right, y down)
    // Then apply the offset to the centre of our lens
    const Scalar2 image =
      (Scalar2)((Scalar)(dimensions.x - 1) * (Scalar)(0.5), (Scalar)(dimensions.y - 1) * (Scalar)(0.5)) - screen
      - centre;

    // Store our output coordinates
    out[index] = image;
}
