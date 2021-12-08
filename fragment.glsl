#version 330 core
#define PI 3.1415925359
out vec4 FragColor;
uniform ivec2 ScreenSize;

uniform float time;
//uniform ivec2 ScreenSize2;

in vec4 vertexColor; // the input variable from the vertex shader (same name and same type)  

const float min_step = 0.01; //our world will be in millimeters, and the minimum step size will be 0.1 millimeter
const float max_step =1000000.0; // maximum distance will be 1km
const int step_limit = 128; // steps of precission

vec3 camera_pos = vec3(0,0,0);
vec3 aim_to = vec3(0,0,1);

int fov=45;
vec2 uv=vec2(gl_FragCoord.x/ScreenSize.x,gl_FragCoord.y/ScreenSize.y);
vec2 suv = (uv-0.5)*2;
vec3 ray_direction = normalize(vec3(sin(radians(suv.x*fov)) , sin(radians(suv.y*fov/ScreenSize.x*ScreenSize.y)),1));

struct Hit{
    vec3 color;
    float dist;
    float reflectivity;
};

struct Light{
    vec3 position;
    float intensity;
};

Light test_light=Light(vec3(0,400,200), 5);

struct Shape{
    vec3 center;
    vec3 rotation;
    vec3 color;
    vec4 properties; // type, prop1, prop2, prop3
    float reflectivity;
};

//properties     x         y           z           w
// sphere        1     ,radius     ,not used   , not used
// CUBE          2     , width     ,height     , depth
// plane         3     ,width      ,depth
// boolean       4     ,index
// cylinder      5     ,height    ,radius

Shape[6] scene= Shape[6](
    Shape(vec3(0,-100,1000),vec3(1,0,0),vec3(1,0,1),vec4(2,100,50,100),0.3),  
    Shape(vec3(50,-50,800),vec3(1,0,0),vec3(1,1,0),vec4(1,50,0,0),0.3),  
    Shape(vec3(300*cos(time*2.5),300*sin(time),1000+300*cos(time*4)),vec3(1,0,0),vec3(sin(time*.5),cos(time*.6),sin(time*.2)+cos(time*.3)),vec4(1,100,0,0),0.3),
    Shape(vec3(0,-500,0),vec3(1,0,0),vec3(1,1,1),vec4(3,10000,10000,0),0.1),
    Shape(vec3(300,-300,1000),vec3(90,0,0),vec3(1,0.5,1),vec4(5,500,100,0),0.8),
    Shape(vec3(-100,-150,500),vec3(0,0,0),vec3(1,1,1),vec4(4,0,0,0),0) 
);

Shape[7] bools = Shape[7](
    Shape(vec3(0,0,300),vec3(0,0,0),vec3(1,0,0),vec4(2,100,100,80),0.3),
    Shape(vec3(0,0,300),vec3(0,0,0),vec3(0,1,1),vec4(1,110,0,0),0),
    Shape(vec3(0,0,250),vec3(0,0,0),vec3(1,1,0),vec4(5,120,60,0),0.13),
    Shape(vec3(0,0,300),vec3(90,0,0),vec3(1,1,1),vec4(5,120,60,0),0.24),
    Shape(vec3(0,-100,300),vec3(0,0,90),vec3(0,0,1),vec4(5,120,60,0),0.85),
    Shape(vec3(150-300*cos(time*0.25),0,-25),vec3(1,0,0),vec3(1,0.25,0),vec4(1,100,100,100),0.3),
    Shape(vec3(0,0,0),vec3(0,0,0),vec3(0,1,0.5),vec4(2,80,80,80),0.3)
);

// 1,4 intersect
// 2,5 union
// 3,6 dif
vec3[6] actions = vec3[6](
    vec3(1,4,2),
    vec3(2,6,10),
    vec3(3,6,10),
    vec3(4,5,3),
    vec3(6,2,30),
    vec3(5,6,50)
);

//BOOLEANS

Hit intersectSDF(Hit A, Hit B) {
    return A.dist > B.dist ? A: B;
}
 
Hit unionSDF(Hit A, Hit B) {
    return A.dist < B.dist ? A: B;
}
 
Hit differenceSDF(Hit A, Hit B) {
    B.dist=-B.dist;
    return A.dist > B.dist ? A: B;
}

 
// SMOOTH BOOLS
 
Hit smoothIntersectSDF(Hit A, Hit B, float smoothing ) 
{
  float h = clamp(0.5 - 0.5*(A.dist - B.dist) / smoothing, 0., 1.);
  float dis=mix(A.dist, B.dist, h ) + smoothing*h*(1.-h);
  return Hit(mix(A.color, B.color, h), dis, mix(A.reflectivity, B.reflectivity,h)); 
}
 
Hit smoothUnionSDF(Hit A, Hit B, float smoothing ) 
{
  float h = clamp(0.5 + 0.5*(A.dist - B.dist) / smoothing, 0., 1.);
  
  float dis=mix(A.dist, B.dist, h ) - smoothing*h*(1.-h);
  return Hit(mix(A.color, B.color, h), dis, mix(A.reflectivity, B.reflectivity,h)); 
}
 
Hit smoothDifferenceSDF(Hit A, Hit B, float smoothing ) 
{
  float h = clamp(0.5 -  0.5*(A.dist + B.dist) / smoothing, 0., 1.);
  float dis=mix(A.dist, -B.dist, h ) + smoothing*h*(1.-h);
  return Hit(A.color, dis, A.reflectivity); 
}
 

// VECTORS
mat2 Rotate(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c,-s,s,c);
}

//SHAPES
float sphereSDF(vec3 point,vec3 center, float radius)
{
    return length(point - center)-radius;
}

float cubeSDF(vec3 point, vec3 center, vec3 size){
    vec3 q = abs(point-center) - size;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float cubeSDF(vec3 point, vec3 center, vec3 rotation, vec3 size){

    
    vec3 p =point-center;
    vec3 rotated_point = p - vec3 (0,0,0); 
    rotated_point.yz *= Rotate(radians(rotation.x)); 
    rotated_point.xz *= Rotate(radians(rotation.y));  
    rotated_point.xy *= Rotate(radians(rotation.z)); 

    vec3 q = abs(rotated_point-center) - size;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float planeSDF(vec3 point, vec3 center, vec2 size){
    vec3 q = abs(point-center) - vec3(size.x,0,size.y);
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float cappedCylinderSDF( vec3 point, vec3 center, float h, float r )
{
    vec2 d = abs(vec2(length(point.xz),point.y)) - vec2(r,h);
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float cappedCylinderSDF( vec3 point, vec3 center, vec3 rotation, float h, float r )
{
    vec3 p =point-center;
    vec3 c1p = p - vec3 (0,0,0); 
    c1p.yz *= Rotate(radians(rotation.x)); 
    c1p.xz *= Rotate(radians(rotation.y));  
    c1p.xy *= Rotate(radians(rotation.z)); 
    vec2 d = abs(vec2(length(c1p.xz),c1p.y)) - vec2(r,h);
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

//TRACING

Hit get_dist_for_bools(Shape shape,vec3 point)
{

    if (shape.properties.x==1) //sphere
        {
            return Hit(shape.color, sphereSDF(point, shape.center, shape.properties.y), shape.reflectivity);
        }
        else if (shape.properties.x==2)//cube
        { 
             return Hit(shape.color, cubeSDF(point, shape.center, shape.properties.yzw),  shape.reflectivity);
        }
        else if (shape.properties.x==3) //plane
        {
            return Hit(shape.color, planeSDF(point, shape.center, shape.properties.yz),  shape.reflectivity);
        }
         else if (shape.properties.x==5)//cyl
         { 
            return Hit(shape.color, cappedCylinderSDF(point, shape.center,shape.rotation,shape.properties.y,shape.properties.z),  shape.reflectivity);
        }
}

Shape move(Shape shape, vec3 displacement){
    shape.center.xyz+=displacement;
    return shape;
}

Hit boolSDF(vec3 point, vec3 center){
    Hit hit=get_dist_for_bools(move(bools[0], center), point);
    for (int action_ind=0;action_ind<actions.length();action_ind++){
        vec3 action=actions[action_ind];
        Hit next_hit=get_dist_for_bools(move(bools[int(action.x)], center), point);
        
        if (action.y==1)
        {
            hit=intersectSDF(hit, next_hit);
        }
        else if (action.y==2) 
        { 
            hit=unionSDF(hit, next_hit);
        }
        else if (action.y==3) 
        { 
            hit=differenceSDF(hit, next_hit);
        }
        else if (action.y==4)
        {   
            hit=smoothIntersectSDF(hit, next_hit, action.z);
        }
        else if (action.y==5) 
        { 
            hit=smoothUnionSDF(hit, next_hit, action.z);
        }
        else if (action.y==6) 
        { 
            hit=smoothDifferenceSDF(hit, next_hit, action.z);
        }
   }
  return hit;
  //return intersectSDF(cubeSDF(point, center, vec3(100,100,100)), sphereSDF(point, center, 120));
}

Hit boolSDF(vec3 point, vec3 center, vec3 rotation){
    vec3 rotated_point = point; 
    rotated_point.yz *= Rotate(radians(rotation.x)); 
    rotated_point.xz *= Rotate(radians(rotation.y));  
    rotated_point.xy *= Rotate(radians(rotation.z)); 
    
    return boolSDF(rotated_point, center);
}


float distance_from_distorted_sphere(vec3 point, vec3 center, float radius)
{
   
    return length(point - center)-radius + 50*sin(5*point.x)+ 50*sin(5*point.y)+ 50*sin(5*point.z);
}

//TRACING

Hit get_dist(Shape shape,vec3 point)
{
    if (shape.properties.x==1) //sphere
        {
            return Hit(shape.color, sphereSDF(point, shape.center, shape.properties.y),  shape.reflectivity);
        }
        else if (shape.properties.x==2)//cube
        { 
             return Hit(shape.color, cubeSDF(point, shape.center, shape.properties.yzw),  shape.reflectivity);
        }
        else if (shape.properties.x==3) //plane
        {
            return Hit(shape.color, planeSDF(point, shape.center, shape.properties.yz),  shape.reflectivity);
        }
         else if (shape.properties.x==4)//boolean
         { 
            return boolSDF(point, shape.center, shape.rotation);
        }
         else if (shape.properties.x==5)//cyl
         { 
            return Hit(shape.color, cappedCylinderSDF(point, shape.center,shape.rotation,shape.properties.y,shape.properties.z),  shape.reflectivity);
        }
}

Hit distance_closest(vec3 point){
    //point.xz *=Rotate(time / 2.0);
    float min_dist=1000000;
    Hit closest=Hit(vec3(0,0,0),1000000,0);

    for (int scene_index =0; scene_index<scene.length();scene_index++ )
    {   Hit hit=get_dist(scene[scene_index], point);
        if (closest.dist>hit.dist)
        {
            closest=hit;
        }
        
    }
    return closest;

}

vec3 GetNormal(vec3 point)
{ 
    float d = distance_closest(point).dist; // Distance
    vec2 e = vec2(.01,0); // Epsilon
 
    vec3 n = d - vec3(
        distance_closest(point-e.xyy).dist,  // e.xyy is the same as vec3(.01,0,0). The x of e is .01. this is called a swizzle
        distance_closest(point-e.yxy).dist,
        distance_closest(point-e.yyx).dist);
 
    return normalize(n);
}


Hit ray_march(vec3 origin, vec3 direction){

    float distance_traveled=0.;
    vec3 color;
    float reflectivity;
    for (int cur_step=0;cur_step<step_limit ; cur_step ++)
    {
         vec3 current_point = origin + distance_traveled * direction;
        
         Hit hit=distance_closest(current_point);
         float dist_close = hit.dist;// distance_closest(current_point);//hit.w;
         color = hit.color;
         reflectivity=hit.reflectivity;
         if(distance_traveled > max_step || dist_close < min_step) break;

         distance_traveled += dist_close;

    }
    return Hit(color, distance_traveled, reflectivity);
}

float getDif(vec3 point, vec3 normal){
    
    vec3 to_light = normalize(test_light.position-point);
    float dif = dot(normal,to_light); // Diffuse light
    dif = clamp(dif,0.,1.); // Clamp so it doesnt go below 0
    return dif;
}

vec4 getRefl(vec3 point, vec3 normal){
    point += normal+min_step*2.;
    
    
	//reflections
    vec3 incoming = point-camera_pos;
    vec3 reflection_ray=normalize(incoming - 2.*dot(normal, incoming)*normal);
    Hit hit =ray_march(point, reflection_ray);
    float dist_to_reflect_hit=hit.dist;
    vec3 color = hit.color;
    float dif=getDif(point, normal);
    return vec4(color*dif, hit.reflectivity);
}

vec3 GetLight(vec3 point, vec3 color)
{ 
    // Directional light
    //vec3 lightPos = test_light.; // Light Position
    vec3 to_light = normalize(test_light.position-point); // Light Vector
    vec3 normal = GetNormal(point); // Normal Vector
   
    float dif = getDif(point, normal);
 
    // Shadows
    float dist_closest_body = ray_march(point+normal*min_step*2., to_light).dist;
    
    if(dist_closest_body<length(test_light.position-point)) dif *= .1;

    vec4 refl=getRefl(point, normal);

    return (dif*test_light.intensity*color*(1-refl.w)+refl.rgb*refl.w);
}


void main()
{   Hit hit=ray_march(camera_pos,ray_direction);
    float dist=hit.dist;
    vec3 point = camera_pos+dist*ray_direction;
    vec3 difuse=GetLight(point,hit.color)*0.2;
    FragColor = vec4(difuse,1);
    //FragColor= vec4(ray_direction,1);
    //FragColor = vec4(suv.xy ,-suv.x,1);
} 