#version 300 es

precision highp float;
precision highp int;
precision highp sampler2D;

#include <pathtracing_uniforms_and_defines>


uniform sampler2D tTriangleTexture;
uniform sampler2D tAABBTexture;

uniform sampler2D tPaintingTexture;
uniform sampler2D tDarkWoodTexture;
uniform sampler2D tLightWoodTexture;
uniform sampler2D tMarbleTexture;
uniform sampler2D tHammeredMetalNormalMapTexture;

uniform mat4 uDoorObjectInvMatrix;
uniform mat3 uDoorObjectNormalMatrix;

#define INV_TEXTURE_WIDTH 0.00048828125

#define N_SPHERES 2
#define N_OPENCYLINDERS 4
#define N_QUADS 8
#define N_BOXES 10

struct Ray { vec3 origin; vec3 direction; };
struct Sphere { float radius; vec3 position; vec3 emission; vec3 color; float roughness; int type; bool isModel; };
struct OpenCylinder { float radius; vec3 pos1; vec3 pos2; vec3 emission; vec3 color; float roughness; int type; bool isModel; };
struct Quad { vec3 v0; vec3 v1; vec3 v2; vec3 v3; vec3 emission; vec3 color; float roughness; int type; bool isModel; };
struct Box { vec3 minCorner; vec3 maxCorner; vec3 emission; vec3 color; float roughness; int type; bool isModel; };
struct Intersection { vec3 normal; vec3 emission; vec3 color; float roughness; vec2 uv; int type; bool isModel; };

Sphere spheres[N_SPHERES];
OpenCylinder openCylinders[N_OPENCYLINDERS];
Quad quads[N_QUADS];
Box boxes[N_BOXES];


#include <pathtracing_random_functions>

#include <pathtracing_calc_fresnel_reflectance>

#include <pathtracing_sphere_intersect>

#include <pathtracing_opencylinder_intersect>

#include <pathtracing_triangle_intersect>

#include <pathtracing_box_intersect>

#include <pathtracing_boundingbox_intersect>

#include <pathtracing_bvhTriangle_intersect>

#include <pathtracing_bvhDoubleSidedTriangle_intersect>


//----------------------------------------------------------------------------
float QuadIntersect( vec3 v0, vec3 v1, vec3 v2, vec3 v3, Ray r )
//----------------------------------------------------------------------------
{
	float tTri1 = TriangleIntersect( v0, v1, v2, r );
	float tTri2 = TriangleIntersect( v0, v2, v3, r );
	return min(tTri1, tTri2);
}

vec3 perturbNormal(vec3 nl, vec2 normalScale, vec2 uv)
{
        vec3 S = normalize( cross( abs(nl.y) < 0.9 ? vec3(0, 1, 0) : vec3(0, 0, 1), nl ) );
        vec3 T = cross(nl, S);
        vec3 N = normalize( nl );
        mat3 tsn = mat3( S, T, N );

        vec3 mapN = texture(tHammeredMetalNormalMapTexture, uv).xyz * 2.0 - 1.0;
        mapN.xy *= normalScale;
        
        return normalize( tsn * mapN );
}

struct StackLevelData
{
        float id;
        float rayT;
} stackLevels[24];

struct BoxNode
{
	float branch_A_Index;
	vec3 minCorner;
	float branch_B_Index;
	vec3 maxCorner;  
};

BoxNode GetBoxNode(const in float i)
{
	// each bounding box's data is encoded in 2 rgba(or xyzw) texture slots 
	float iX2 = (i * 2.0);
	// (iX2 + 0.0) corresponds to .x: idLeftChild, .y: aabbMin.x, .z: aabbMin.y, .w: aabbMin.z 
	// (iX2 + 1.0) corresponds to .x: idRightChild .y: aabbMax.x, .z: aabbMax.y, .w: aabbMax.z 

	ivec2 uv0 = ivec2( mod(iX2 + 0.0, 2048.0), floor((iX2 + 0.0) * INV_TEXTURE_WIDTH) );
	ivec2 uv1 = ivec2( mod(iX2 + 1.0, 2048.0), floor((iX2 + 1.0) * INV_TEXTURE_WIDTH) );
	
	vec4 aabbNodeData0 = texelFetch(tAABBTexture, uv0, 0);
	vec4 aabbNodeData1 = texelFetch(tAABBTexture, uv1, 0);
	

	BoxNode BN = BoxNode( aabbNodeData0.x,
			      aabbNodeData0.yzw,
			      aabbNodeData1.x,
			      aabbNodeData1.yzw );

        return BN;
}


//-----------------------------------------------------------------------
float SceneIntersect( Ray r, inout Intersection intersec )
//-----------------------------------------------------------------------
{
	vec3 normal;
        float d;
	float t = INFINITY;

	vec4 aabbNodeData;
	vec4 vd0, vd1, vd2, vd3, vd4, vd5, vd6, vd7;
	vec3 aabbMin, aabbMax;
	vec3 inverseDir = 1.0 / r.direction;
	vec3 hitPos, toLightBulb;
	ivec2 uv0, uv1, uv2, uv3, uv4, uv5, uv6, uv7;

        float stackptr = 0.0;	
	float bc, bd;
	float id = 0.0;
	float tu, tv;
	float triangleID = 0.0;
	float triangleU = 0.0;
	float triangleV = 0.0;
	float triangleW = 0.0;
	
	bool skip = false;
	bool triangleHit = false;

	BoxNode currentBoxNode, nodeA, nodeB, tnp;
	StackLevelData currentStackData, slDataA, slDataB, tmp;
			
	// ROOM
	for (int i = 0; i < N_QUADS; i++)
        {
		d = QuadIntersect( quads[i].v0, quads[i].v1, quads[i].v2, quads[i].v3, r );
		if (d < t && d > 0.0)
		{
			if (i == 1) // check back wall quad for door portal opening
			{
				vec3 ip = r.origin + r.direction * d;
				if (ip.x > 180.0 && ip.x < 280.0 && ip.y > -100.0 && ip.y < 90.0)
					continue;
			}
			
			t = d;
			intersec.normal = normalize( cross(quads[i].v1 - quads[i].v0, quads[i].v2 - quads[i].v0) );
			intersec.emission = quads[i].emission;
			intersec.color = quads[i].color;
			intersec.type = quads[i].type;
			intersec.isModel = false;
		}
        }
	
	for (int i = 0; i < N_BOXES - 1; i++)
        {
		d = BoxIntersect( boxes[i].minCorner, boxes[i].maxCorner, r, normal );
		if (d < t)
		{
			t = d;
			intersec.normal = normalize(normal);
			intersec.emission = boxes[i].emission;
			intersec.color = boxes[i].color;
			intersec.type = boxes[i].type;
			intersec.isModel = false;
		}
	}
	
	// DOOR (TALL BOX)
	Ray rObj;
	// transform ray into Tall Box's object space
	rObj.origin = vec3( uDoorObjectInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uDoorObjectInvMatrix * vec4(r.direction, 0.0) );
	d = BoxIntersect( boxes[9].minCorner, boxes[9].maxCorner, rObj, normal );
	
	if (d < t)
	{	
		t = d;
		
		// transfom normal back into world space
		normal = vec3(uDoorObjectNormalMatrix * normal);
		
		intersec.normal = normalize(normal);
		intersec.emission = boxes[9].emission;
		intersec.color = boxes[9].color;
		intersec.type = boxes[9].type;
		intersec.isModel = false;
	}
	
	for (int i = 0; i < N_OPENCYLINDERS; i++)
        {
		d = OpenCylinderIntersect( openCylinders[i].pos1, openCylinders[i].pos2, openCylinders[i].radius, r, normal );
		if (d < t)
		{
			t = d;
			intersec.normal = normalize(normal);
			intersec.emission = openCylinders[i].emission;
			intersec.color = openCylinders[i].color;
			intersec.type = openCylinders[i].type;
			intersec.isModel = false;
		}
        }
	
	for (int i = 0; i < N_SPHERES; i++)
        {
		d = SphereIntersect( spheres[i].radius, spheres[i].position, rObj );
		if (d < t)
		{
			t = d;

			normal = normalize((rObj.origin + rObj.direction * t) - spheres[i].position);
			normal = vec3(uDoorObjectNormalMatrix * normal);
			intersec.normal = normalize(normal);
			intersec.emission = spheres[i].emission;
			intersec.color = spheres[i].color;
			intersec.type = spheres[i].type;
			intersec.isModel = false;
		}
	}

	currentBoxNode = GetBoxNode(stackptr);
	currentStackData = StackLevelData(stackptr, BoundingBoxIntersect(currentBoxNode.minCorner, currentBoxNode.maxCorner, r.origin, inverseDir));
	stackLevels[0] = currentStackData;
	
	while (true)
        {
		if (currentStackData.rayT < t) 
                {
                        if (currentBoxNode.branch_A_Index < 0.0) //  < 0.0 signifies a leaf node
                        {
				// each triangle's data is encoded in 8 rgba(or xyzw) texture slots
				id = 8.0 * (-currentBoxNode.branch_A_Index - 1.0);

				uv0 = ivec2( mod(id + 0.0, 2048.0), floor((id + 0.0) * INV_TEXTURE_WIDTH) );
				uv1 = ivec2( mod(id + 1.0, 2048.0), floor((id + 1.0) * INV_TEXTURE_WIDTH) );
				uv2 = ivec2( mod(id + 2.0, 2048.0), floor((id + 2.0) * INV_TEXTURE_WIDTH) );
				
				vd0 = texelFetch(tTriangleTexture, uv0, 0);
				vd1 = texelFetch(tTriangleTexture, uv1, 0);
				vd2 = texelFetch(tTriangleTexture, uv2, 0);

				d = BVH_DoubleSidedTriangleIntersect( vec3(vd0.xyz), vec3(vd0.w, vd1.xy), vec3(vd1.zw, vd2.x), r, tu, tv );

				if (d < t && d > 0.0)
				{
					t = d;
					triangleID = id;
					triangleU = tu;
					triangleV = tv;
					triangleHit = true;
				}
                        }
                        else // else this is a branch
                        {
                                nodeA = GetBoxNode(currentBoxNode.branch_A_Index);
                                nodeB = GetBoxNode(currentBoxNode.branch_B_Index);
                                slDataA = StackLevelData(currentBoxNode.branch_A_Index, BoundingBoxIntersect(nodeA.minCorner, nodeA.maxCorner, r.origin, inverseDir));
                                slDataB = StackLevelData(currentBoxNode.branch_B_Index, BoundingBoxIntersect(nodeB.minCorner, nodeB.maxCorner, r.origin, inverseDir));
				
				// first sort the branch node data so that 'a' is the smallest
				if (slDataB.rayT < slDataA.rayT)
				{
					tmp = slDataB;
					slDataB = slDataA;
					slDataA = tmp;

					tnp = nodeB;
					nodeB = nodeA;
					nodeA = tnp;
				} // branch 'b' now has the larger rayT value of 'a' and 'b'

				if (slDataB.rayT < t) // see if branch 'b' (the larger rayT) needs to be processed
				{
					currentStackData = slDataB;
					currentBoxNode = nodeB;
					skip = true; // this will prevent the stackptr from decreasing by 1
				}
				if (slDataA.rayT < t) // see if branch 'a' (the smaller rayT) needs to be processed 
				{
					if (skip == true) // if larger branch 'b' needed to be processed also,
						stackLevels[int(stackptr++)] = slDataB; // cue larger branch 'b' for future round
								// also, increase pointer by 1
					
					currentStackData = slDataA;
					currentBoxNode = nodeA;
					skip = true; // this will prevent the stackptr from decreasing by 1
				}
                        }
		} // end if (currentStackData.rayT < t)

		if (skip == false) 
                {
                        // decrease pointer by 1 (0.0 is root level, 24.0 is maximum depth)
                        if (--stackptr < 0.0) // went past the root level, terminate loop
                                break;
                        currentStackData = stackLevels[int(stackptr)];
                        currentBoxNode = GetBoxNode(currentStackData.id);
                }
		skip = false; // reset skip

        } // end while (true)


	if (triangleHit)
	{
		//uv0 = ivec2( mod(triangleID + 0.0, 2048.0), floor((triangleID + 0.0) * INV_TEXTURE_WIDTH) );
		//uv1 = ivec2( mod(triangleID + 1.0, 2048.0), floor((triangleID + 1.0) * INV_TEXTURE_WIDTH) );
		uv2 = ivec2( mod(triangleID + 2.0, 2048.0), floor((triangleID + 2.0) * INV_TEXTURE_WIDTH) );
		uv3 = ivec2( mod(triangleID + 3.0, 2048.0), floor((triangleID + 3.0) * INV_TEXTURE_WIDTH) );
		uv4 = ivec2( mod(triangleID + 4.0, 2048.0), floor((triangleID + 4.0) * INV_TEXTURE_WIDTH) );
		uv5 = ivec2( mod(triangleID + 5.0, 2048.0), floor((triangleID + 5.0) * INV_TEXTURE_WIDTH) );
		uv6 = ivec2( mod(triangleID + 6.0, 2048.0), floor((triangleID + 6.0) * INV_TEXTURE_WIDTH) );
		uv7 = ivec2( mod(triangleID + 7.0, 2048.0), floor((triangleID + 7.0) * INV_TEXTURE_WIDTH) );
		
		//vd0 = texelFetch(tTriangleTexture, uv0, 0);
		//vd1 = texelFetch(tTriangleTexture, uv1, 0);
		vd2 = texelFetch(tTriangleTexture, uv2, 0);
		vd3 = texelFetch(tTriangleTexture, uv3, 0);
		vd4 = texelFetch(tTriangleTexture, uv4, 0);
		vd5 = texelFetch(tTriangleTexture, uv5, 0);
		vd6 = texelFetch(tTriangleTexture, uv6, 0);
		vd7 = texelFetch(tTriangleTexture, uv7, 0);

		// face normal for flat-shaded polygon look
		//intersec.normal = normalize( cross(vec3(vd0.w, vd1.xy) - vec3(vd0.xyz), vec3(vd1.zw, vd2.x) - vec3(vd0.xyz)) );
		
		// interpolated normal using triangle intersection's uv's
		triangleW = 1.0 - triangleU - triangleV;
		intersec.normal = normalize(triangleW * vec3(vd2.yzw) + triangleU * vec3(vd3.xyz) + triangleV * vec3(vd3.w, vd4.xy));
		intersec.emission = vec3(1, 0, 1); // use this if intersec.type will be LIGHT
		intersec.color = vd6.yzw;
		intersec.uv = triangleW * vec2(vd4.zw) + triangleU * vec2(vd5.xy) + triangleV * vec2(vd5.zw);
		intersec.type = int(vd6.x);
		//intersec.albedoTextureID = int(vd7.x);
		intersec.isModel = true;
	}
	
	return t;
	
}


#define EYE_PATH_LENGTH    4
#define LIGHT_PATH_LENGTH  1  // Only 1 ray cast from light source is necessary because the light just needs to find its way through
				// the crack in the doorway and land on a wall, where it can be connected with the eye path later

//-----------------------------------------------------------------------
vec3 CalculateRadiance( Ray r, inout uvec2 seed )
//-----------------------------------------------------------------------
{
	Intersection intersec;
	vec4 texColor;

	vec3 randVec = vec3(rand(seed) * 2.0 - 1.0, rand(seed) * 2.0 - 1.0, rand(seed) * 2.0 - 1.0);
	vec3 accumCol = vec3(0);
	vec3 maskEyePath = vec3(1);
	vec3 maskLightPath = vec3(1);
	vec3 eyeX = vec3(0);
	vec3 lightX = vec3(0);
	vec3 checkCol0 = vec3(0.01);
	vec3 checkCol1 = vec3(1.0);
	vec3 nl, n, x;
	vec3 nlEyePath = vec3(0);
	vec3 tdir;

	vec2 sampleUV;
	
	float nc, nt, Re;
	float t = INFINITY;
	float epsIntersect = 0.01;

	int diffuseCount = 0;
	int previousIntersecType = -1;

	bool bounceIsSpecular = true;
	//set following flag to true - we haven't found a diffuse surface yet and can exit early (keeps frame rate high)
	bool skipConnectionEyePath = true;

	
	// Eye path tracing (from Camera) ///////////////////////////////////////////////////////////////////////////
	
	for (int bounces = 0; bounces < EYE_PATH_LENGTH; bounces++)
	{
	
		t = SceneIntersect(r, intersec);
		
		// not needed, light can't escape from the small room in this scene
		/*
		if (t == INFINITY)
		{
			break;
		}
		*/
		
		if (intersec.type == LIGHT)
		{
			if (bounceIsSpecular)
			{
				accumCol = maskEyePath * intersec.emission;
			
				skipConnectionEyePath = true;
			}
			
			break;
		}
		
		// useful data 
		n = normalize(intersec.normal);
		nl = dot(n, r.direction) < 0.0 ? normalize(n) : normalize(n * -1.0);
		x = r.origin + r.direction * t;
		
		
		if ( intersec.type == DIFF || intersec.type == LIGHTWOOD ||
		     intersec.type == DARKWOOD || intersec.type == PAINTING ) // Ideal DIFFUSE reflection
		{
			
			if (intersec.type == LIGHTWOOD)
			{
				if (abs(nl.x) > 0.5) sampleUV = vec2(x.z, x.y);
				else if (abs(nl.y) > 0.5) sampleUV = vec2(x.x, x.z);
				else sampleUV = vec2(x.x, x.y);
				texColor = texture(tLightWoodTexture, sampleUV * 0.01);
				intersec.color *= GammaToLinear(texColor, 2.2).rgb;
			}
			else if (intersec.type == DARKWOOD)
			{
				sampleUV = vec2( uDoorObjectInvMatrix * vec4(x, 1.0) );
				texColor = texture(tDarkWoodTexture, sampleUV * vec2(0.01,0.005));
				intersec.color *= GammaToLinear(texColor, 2.2).rgb;
			}
			else if (intersec.type == PAINTING)
			{
				sampleUV = vec2((55.0 + x.x) / 110.0, (x.y - 20.0) / 44.0);
				texColor = texture(tPaintingTexture, sampleUV);
				intersec.color *= GammaToLinear(texColor, 2.2).rgb;
			}
					
			maskEyePath *= intersec.color;
			eyeX = x + nl;
			nlEyePath = nl;
			skipConnectionEyePath = false;
			bounceIsSpecular = false;
			previousIntersecType = DIFF;
			
			diffuseCount++;
			if (diffuseCount > 1 || rand(seed) < 0.5)
			{
				break;
			}
				
			// choose random Diffuse sample vector
			r = Ray( x, randomCosWeightedDirectionInHemisphere(nl, seed) );
			r.origin += nl * epsIntersect;
			eyeX = r.origin;
			continue;
		}
		
		if (intersec.type == SPEC)  // Ideal SPECULAR reflection
		{
			maskEyePath *= intersec.color;
			
			if (intersec.isModel)
				nl = perturbNormal(nl, vec2(-0.2, 0.2), intersec.uv * 2.0);

			vec3 reflectVec = reflect(r.direction, nl);
			vec3 glossyVec = randomDirectionInHemisphere(nl, seed);
			r = Ray( x, mix(reflectVec, glossyVec, intersec.roughness) );
			r.origin += nl * epsIntersect;

			previousIntersecType = SPEC;
			skipConnectionEyePath = true;
			continue;
		}
		
		
		if (intersec.type == REFR)  // Ideal dielectric refraction
		{	
			nc = 1.0; // IOR of Air
			nt = 1.5; // IOR of common Glass
			Re = calcFresnelReflectance(n, nl, r.direction, nc, nt, tdir);
			skipConnectionEyePath = true;

			if (rand(seed) < Re) // reflect ray from surface
			{
				r = Ray( x, reflect(r.direction, nl) );
				r.origin += nl * epsIntersect;
				
				previousIntersecType = REFR;
				continue;	
			}
			else // transmit ray through surface
			{
				if (previousIntersecType == DIFF) 
					maskEyePath *= 4.0;
			
				previousIntersecType = REFR;
			
				maskEyePath *= intersec.color;
				r = Ray(x, tdir);
				r.origin -= nl * epsIntersect;

				continue;
			}	
		} // end if (intersec.type == REFR)
		
		if (intersec.type == COAT || intersec.type == CHECK)  // Diffuse object underneath with ClearCoat on top
		{	
			nc = 1.0; // IOR of Air
			nt = 1.4; // IOR of ClearCoat
			Re = calcFresnelReflectance(n, nl, r.direction, nc, nt, tdir);
			
			previousIntersecType = COAT;
			
			// choose either specular reflection or diffuse
			if( rand(seed) < Re )
			{	
				vec3 reflectVec = reflect(r.direction, nl);
				vec3 glossyVec = randomDirectionInHemisphere(nl, seed);
				r = Ray( x, mix(reflectVec, glossyVec, intersec.roughness) );
				r.origin += nl * epsIntersect;
				
				skipConnectionEyePath = true;
				continue;	
			}
			else
			{
				if (intersec.type == CHECK)
				{
					float q = clamp( mod( dot( floor(x.xz * 0.04), vec2(1.0) ), 2.0 ) , 0.0, 1.0 );
					intersec.color = checkCol0 * q + checkCol1 * (1.0 - q);	
				}
				
				//if (intersec.color.r == 0.99) // tag for marble ellipsoid
				if (intersec.type == COAT)
				{
					// spherical coordinates
					//sampleUV.x = atan(-nl.z, nl.x) * ONE_OVER_TWO_PI + 0.5;
					//sampleUV.y = asin(clamp(nl.y, -1.0, 1.0)) * ONE_OVER_PI + 0.5;
					texColor = texture(tMarbleTexture, intersec.uv);
					texColor = clamp(texColor + vec4(0.1), 0.0, 1.0);
					//intersec.color *= GammaToLinear(texColor, 2.2).rgb;
					intersec.color = GammaToLinear(texColor, 2.2).rgb;
				}
				
				diffuseCount++;

				skipConnectionEyePath = false;
				bounceIsSpecular = false;
				maskEyePath *= intersec.color;
				
				eyeX = x + nl;
				nlEyePath = nl;
				
				// choose random sample vector for diffuse material underneath ClearCoat
				r = Ray( x, randomCosWeightedDirectionInHemisphere(nl, seed) );
				r.origin += nl * epsIntersect;
				continue;	
			}	
		} //end if (intersec.type == COAT)
		
	} // end for (int bounces = 0; bounces < EYE_PATH_LENGTH; bounces++)
	
	
	if (skipConnectionEyePath)
		return accumCol;
	
	
	// Light path tracing (from Light source) /////////////////////////////////////////////////////////////////////

	vec3 randPointOnLight;
	randPointOnLight.x = mix(quads[0].v0.x, quads[0].v1.x, rand(seed));
	randPointOnLight.y = mix(quads[0].v0.y, quads[0].v3.y, rand(seed));
	randPointOnLight.z = quads[0].v0.z;
	vec3 randLightDir = randomCosWeightedDirectionInHemisphere(vec3(0,0,1), seed);
	vec3 nlLightPath = vec3(0,0,1);
	bool diffuseReached = false;
	randLightDir = normalize(randLightDir);
	r = Ray( randPointOnLight, randLightDir );
	r.origin += r.direction; // move light ray out to prevent self-intersection with light
	lightX = r.origin;
	maskLightPath = quads[0].emission;
	
	
	for (int bounces = 0; bounces < LIGHT_PATH_LENGTH; bounces++)
	{
		// this lets the original light be the only node on the light path, about 50% of the time
		if (rand(seed) < 0.5)
		{
			break;
		}
				
		t = SceneIntersect(r, intersec);

		if ( intersec.type != DIFF )
		{
			break;
		}
		
		// useful data 
		n = normalize(intersec.normal);
		nl = dot(n, r.direction) < 0.0 ? normalize(n) : normalize(n * -1.0);
		x = r.origin + r.direction * t;
		
		
		//if (intersec.type == DIFF)
		{
			maskLightPath *= intersec.color;
			lightX = x + nl;
			nlLightPath = nl;
			diffuseReached = true;
			break;
		}
		
	} // end for (int bounces = 0; bounces < LIGHT_PATH_LENGTH; bounces++)
	
	
	// Connect Camera path and Light path ////////////////////////////////////////////////////////////
	
	Ray connectRay = Ray(eyeX, normalize(lightX - eyeX));
	float connectDist = distance(eyeX, lightX);
	float c = SceneIntersect(connectRay, intersec);
	if (c < connectDist)
		return accumCol;
	else
	{
		maskEyePath *= max(0.0, dot(connectRay.direction, nlEyePath));

		if (diffuseReached)
			maskLightPath *= max(0.0, dot(-connectRay.direction, nlLightPath));

		accumCol = (maskEyePath * maskLightPath);
	}
	
	return accumCol;      
}


//-----------------------------------------------------------------------
void SetupScene(void)
//-----------------------------------------------------------------------
{
	vec3 z  = vec3(0.0);// No color value, Black        
	//vec3 L1 = vec3(1.0) * 6.0;// Bright White light
	vec3 L2 = vec3(1.0, 0.9, 0.8) * 3.0;// Bright Yellowish light
	vec3 tableColor = vec3(1.0, 0.7, 0.4) * 0.6;
	vec3 brassColor = vec3(1.0, 0.7, 0.5) * 0.7;
	
	quads[0] = Quad( vec3( 180,-100,-299), vec3( 280,-100,-299), vec3( 280,  90,-299), vec3( 180,  90,-299), L2, z, 0.0, LIGHT, false);// Area Light Quad in doorway
	
	quads[1] = Quad( vec3(-350,-100,-300), vec3( 350,-100,-300), vec3( 350, 150,-300), vec3(-350, 150,-300),  z, vec3(1.0), 0.0,   DIFF, false);// Back Wall (in front of camera, visible at startup)
	quads[2] = Quad( vec3( 350,-100, 200), vec3(-350,-100, 200), vec3(-350, 150, 200), vec3( 350, 150, 200),  z, vec3(1.0), 0.0,   DIFF, false);// Front Wall (behind camera, not visible at startup)
	quads[3] = Quad( vec3(-350,-100, 200), vec3(-350,-100,-300), vec3(-350, 150,-300), vec3(-350, 150, 200),  z, vec3(1.0), 0.0,   DIFF, false);// Left Wall
	quads[4] = Quad( vec3( 350,-100,-300), vec3( 350,-100, 200), vec3( 350, 150, 200), vec3( 350, 150,-300),  z, vec3(1.0), 0.0,   DIFF, false);// Right Wall
	quads[5] = Quad( vec3(-350, 150,-300), vec3( 350, 150,-300), vec3( 350, 150, 200), vec3(-350, 150, 200),  z, vec3(1.0), 0.0,   DIFF, false);// Ceiling
	quads[6] = Quad( vec3(-350,-100,-300), vec3(-350,-100, 200), vec3( 350,-100, 200), vec3( 350,-100,-300),  z, vec3(1.0), 0.0,  CHECK, false);// Floor
	
	quads[7] = Quad( vec3(-55, 20,-295), vec3( 55, 20,-295), vec3( 55, 65,-295), vec3(-55, 65,-295), z, vec3(1.0), 0.0, PAINTING, false);// Wall Painting
	
	boxes[0] = Box( vec3(-100,-60,-230), vec3(100,-57,-130), z, vec3(1.0), 0.0, LIGHTWOOD, false);// Table Top
	boxes[1] = Box( vec3(-90,-100,-150), vec3(-84,-60,-144), z, vec3(0.8, 0.85, 0.9),  0.1, SPEC, false);// Table leg left front
	boxes[2] = Box( vec3(-90,-100,-220), vec3(-84,-60,-214), z, vec3(0.8, 0.85, 0.9),  0.1, SPEC, false);// Table leg left rear
	boxes[3] = Box( vec3( 84,-100,-150), vec3( 90,-60,-144), z, vec3(0.8, 0.85, 0.9),  0.1, SPEC, false);// Table leg right front
	boxes[4] = Box( vec3( 84,-100,-220), vec3( 90,-60,-214), z, vec3(0.8, 0.85, 0.9),  0.1, SPEC, false);// Table leg right rear
	
	boxes[5] = Box( vec3(-60, 15, -299), vec3( 60, 70, -296), z, vec3(0.01, 0, 0), 0.3, SPEC, false);// Painting Frame
	
	boxes[6] = Box( vec3( 172,-100,-302), vec3( 180,  98,-299), z, vec3(0.001), 0.3, SPEC, false);// Door Frame left
	boxes[7] = Box( vec3( 280,-100,-302), vec3( 288,  98,-299), z, vec3(0.001), 0.3, SPEC, false);// Door Frame right
	boxes[8] = Box( vec3( 172,  90,-302), vec3( 288,  98,-299), z, vec3(0.001), 0.3, SPEC, false);// Door Frame top
	boxes[9] = Box( vec3(   0, -94,  -3), vec3( 101,  95,   3), z, vec3(0.7), 0.0, DARKWOOD, false);// Door
	
	openCylinders[0] = OpenCylinder( 1.5, vec3( 179,  64,-297), vec3( 179,  80,-297), z, brassColor, 0.2, SPEC, false);// Door Hinge upper
	openCylinders[1] = OpenCylinder( 1.5, vec3( 179,  -8,-297), vec3( 179,   8,-297), z, brassColor, 0.2, SPEC, false);// Door Hinge middle
	openCylinders[2] = OpenCylinder( 1.5, vec3( 179, -80,-297), vec3( 179, -64,-297), z, brassColor, 0.2, SPEC, false);// Door Hinge lower
	
	spheres[0] = Sphere( 4.0, vec3( 88, -10,  7.8), z, brassColor, 0.0, SPEC, false);// Door knob front
	spheres[1] = Sphere( 4.0, vec3( 88, -10, -7), z, brassColor, 0.0, SPEC, false);// Door knob back
}



#include <pathtracing_main>
