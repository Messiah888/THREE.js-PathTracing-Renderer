#version 300 es

precision highp float;
precision highp int;
precision highp sampler2D;

uniform mat4 uEllipsoidTranslateInvMatrix;
uniform mat4 uEllipsoidRotateInvMatrix;
uniform mat4 uEllipsoidScaleInvMatrix;
uniform mat4 uEllipsoidClipInvMatrix;

uniform mat4 uCylinderTranslateInvMatrix;
uniform mat4 uCylinderRotateInvMatrix;
uniform mat4 uCylinderScaleInvMatrix;
uniform mat4 uCylinderClipInvMatrix;

uniform mat4 uConeTranslateInvMatrix;
uniform mat4 uConeRotateInvMatrix;
uniform mat4 uConeScaleInvMatrix;
uniform mat4 uConeClipInvMatrix;

uniform mat4 uParaboloidTranslateInvMatrix;
uniform mat4 uParaboloidRotateInvMatrix;
uniform mat4 uParaboloidScaleInvMatrix;
uniform mat4 uParaboloidClipInvMatrix;

uniform mat4 uHyperboloidTranslateInvMatrix;
uniform mat4 uHyperboloidRotateInvMatrix;
uniform mat4 uHyperboloidScaleInvMatrix;
uniform mat4 uHyperboloidClipInvMatrix;

uniform mat4 uHyperbolicParaboloidTranslateInvMatrix;
uniform mat4 uHyperbolicParaboloidRotateInvMatrix;
uniform mat4 uHyperbolicParaboloidScaleInvMatrix;
uniform mat4 uHyperbolicParaboloidClipInvMatrix;

#include <pathtracing_uniforms_and_defines>

#define N_SPHERES 4

struct Ray { vec3 origin; vec3 direction; };
struct Sphere { float radius; vec3 position; vec3 emission; vec3 color; int type; };
struct Intersection { vec3 normal; vec3 emission; vec3 color; int type; };

Sphere spheres[N_SPHERES];


#include <pathtracing_random_functions>

#include <pathtracing_calc_fresnel_reflectance>

#include <pathtracing_sphere_intersect>

#include <pathtracing_ellipsoid_param_intersect>

#include <pathtracing_cylinder_param_intersect>

#include <pathtracing_cone_param_intersect>

#include <pathtracing_paraboloid_param_intersect>

#include <pathtracing_hyperboloid_param_intersect>

#include <pathtracing_hyperbolic_paraboloid_param_intersect>

#include <pathtracing_sample_sphere_light>



//-----------------------------------------------------------------------
float SceneIntersect( Ray r, inout Intersection intersec )
//-----------------------------------------------------------------------
{
	float d;
	float t = INFINITY;
	float angleAmount = (sin(uTime) * 0.5 + 0.5);
	vec3 n;
	
        for (int i = 0; i < N_SPHERES; i++)
        {
		d = SphereIntersect( spheres[i].radius, spheres[i].position, r );
		if (d < t)
		{
			t = d;
			intersec.normal = normalize((r.origin + r.direction * t) - spheres[i].position);
			intersec.emission = spheres[i].emission;
			intersec.color = spheres[i].color;
			intersec.type = spheres[i].type;
		}
	}
	
        Ray rObj;
	
	// transform ray into Ellipsoid Param's object space
	rObj.origin = vec3( uEllipsoidTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uEllipsoidTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = EllipsoidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		//vec3 ellipsoidPos = vec3(-uEllipsoidTranslateInvMatrix[3][0], -uEllipsoidTranslateInvMatrix[3][1], -uEllipsoidTranslateInvMatrix[3][2]);
		intersec.normal = normalize(transpose(mat3(uEllipsoidTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 0.3, 1.0);
		intersec.type = SPEC;
	}

	// transform ray into Ellipsoid Param's object space
	rObj.origin = vec3( uEllipsoidRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uEllipsoidRotateInvMatrix * vec4(r.direction, 0.0) );
	d = EllipsoidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uEllipsoidRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 0.3, 1.0);
		intersec.type = REFR;
	}

	// transform ray into Ellipsoid Param's object space
	rObj.origin = vec3( uEllipsoidScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uEllipsoidScaleInvMatrix * vec4(r.direction, 0.0) );
	d = EllipsoidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uEllipsoidScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 0.3, 1.0);
		intersec.type = DIFF;
	}

	// transform ray into Ellipsoid Param's object space
	rObj.origin = vec3( uEllipsoidClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uEllipsoidClipInvMatrix * vec4(r.direction, 0.0) );
	d = EllipsoidParamIntersect(-0.8, 0.8, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uEllipsoidClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 0.3, 1.0);
		intersec.type = COAT;
	}

	// transform ray into Cylinder Param's object space
	rObj.origin = vec3( uCylinderTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uCylinderTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = CylinderParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uCylinderTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 0.0);
		intersec.type = SPEC;
	}

	// transform ray into Cylinder Param's object space
	rObj.origin = vec3( uCylinderRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uCylinderRotateInvMatrix * vec4(r.direction, 0.0) );
	d = CylinderParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uCylinderRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 0.0);
		intersec.type = REFR;
	}

	// transform ray into Cylinder Param's object space
	rObj.origin = vec3( uCylinderScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uCylinderScaleInvMatrix * vec4(r.direction, 0.0) );
	d = CylinderParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uCylinderScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 0.0);
		intersec.type = DIFF;
	}

	// transform ray into Cylinder Param's object space
	rObj.origin = vec3( uCylinderClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uCylinderClipInvMatrix * vec4(r.direction, 0.0) );
	d = CylinderParamIntersect(-1.0, 1.0, TWO_PI * 0.6, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uCylinderClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 0.0);
		intersec.type = COAT;
	}

	// transform ray into Cone Param's object space
	rObj.origin = vec3( uConeTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uConeTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = ConeParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uConeTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.2, 0.0);
		intersec.type = SPEC;
	}

	// transform ray into Cone Param's object space
	rObj.origin = vec3( uConeRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uConeRotateInvMatrix * vec4(r.direction, 0.0) );
	d = ConeParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uConeRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.2, 0.0);
		intersec.type = REFR;
	}

	// transform ray into Cone Param's object space
	rObj.origin = vec3( uConeScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uConeScaleInvMatrix * vec4(r.direction, 0.0) );
	d = ConeParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uConeScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.2, 0.0);
		intersec.type = DIFF;
	}

	// transform ray into Cone Param's object space
	rObj.origin = vec3( uConeClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uConeClipInvMatrix * vec4(r.direction, 0.0) );
	d = ConeParamIntersect(-1.0, 1.0, TWO_PI * angleAmount, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uConeClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.2, 0.0);
		intersec.type = COAT;
	}

	// transform ray into Paraboloid Param's object space
	rObj.origin = vec3( uParaboloidTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uParaboloidTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = ParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uParaboloidTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 1.0);
		intersec.type = SPEC;
	}

	// transform ray into Paraboloid Param's object space
	rObj.origin = vec3( uParaboloidRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uParaboloidRotateInvMatrix * vec4(r.direction, 0.0) );
	d = ParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uParaboloidRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 1.0);
		intersec.type = REFR;
	}

	// transform ray into Paraboloid Param's object space
	rObj.origin = vec3( uParaboloidScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uParaboloidScaleInvMatrix * vec4(r.direction, 0.0) );
	d = ParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uParaboloidScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 1.0);
		intersec.type = DIFF;
	}

	// transform ray into Paraboloid Param's object space
	rObj.origin = vec3( uParaboloidClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uParaboloidClipInvMatrix * vec4(r.direction, 0.0) );
	d = ParaboloidParamIntersect(-angleAmount, 1.0 - angleAmount, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uParaboloidClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 0.0, 1.0);
		intersec.type = COAT;
	}

	// transform ray into Hyperboloid Param's object space
	rObj.origin = vec3( uHyperboloidTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperboloidTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = HyperboloidParamIntersect(8.0, -1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperboloidTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 1.0, 0.0);
		intersec.type = SPEC;
	}

	// transform ray into Hyperboloid Param's object space
	rObj.origin = vec3( uHyperboloidRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperboloidRotateInvMatrix * vec4(r.direction, 0.0) );
	d = HyperboloidParamIntersect(8.0, -1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperboloidRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 1.0, 0.0);
		intersec.type = REFR;
	}

	// transform ray into Hyperboloid Param's object space
	rObj.origin = vec3( uHyperboloidScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperboloidScaleInvMatrix * vec4(r.direction, 0.0) );
	d = HyperboloidParamIntersect(8.0, -1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperboloidScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 1.0, 0.0);
		intersec.type = DIFF;
	}

	// transform ray into Hyperboloid Param's object space
	rObj.origin = vec3( uHyperboloidClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperboloidClipInvMatrix * vec4(r.direction, 0.0) );
	d = HyperboloidParamIntersect(floor(mix(-40.0, 40.0, angleAmount)) - 0.5, -1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperboloidClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(1.0, 1.0, 0.0);
		intersec.type = COAT;
	}

	// transform ray into HyperbolicParaboloid Param's object space
	rObj.origin = vec3( uHyperbolicParaboloidTranslateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperbolicParaboloidTranslateInvMatrix * vec4(r.direction, 0.0) );
	d = HyperbolicParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperbolicParaboloidTranslateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 1.0, 0.0);
		intersec.type = SPEC;
	}

	// transform ray into HyperbolicParaboloid Param's object space
	rObj.origin = vec3( uHyperbolicParaboloidRotateInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperbolicParaboloidRotateInvMatrix * vec4(r.direction, 0.0) );
	d = HyperbolicParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperbolicParaboloidRotateInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 1.0, 0.0);
		intersec.type = REFR;
	}

	// transform ray into HyperbolicParaboloid Param's object space
	rObj.origin = vec3( uHyperbolicParaboloidScaleInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperbolicParaboloidScaleInvMatrix * vec4(r.direction, 0.0) );
	d = HyperbolicParaboloidParamIntersect(-1.0, 1.0, TWO_PI, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperbolicParaboloidScaleInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 1.0, 0.0);
		intersec.type = DIFF;
	}

	// transform ray into HyperbolicParaboloid Param's object space
	rObj.origin = vec3( uHyperbolicParaboloidClipInvMatrix * vec4(r.origin, 1.0) );
	rObj.direction = vec3( uHyperbolicParaboloidClipInvMatrix * vec4(r.direction, 0.0) );
	d = HyperbolicParaboloidParamIntersect(-1.0, (1.0 - angleAmount) * 1.9 + 0.1, TWO_PI * (1.0 - angleAmount) + 0.1, rObj.origin, rObj.direction, n);

	if (d < t)
	{
		t = d;
		intersec.normal = normalize(transpose(mat3(uHyperbolicParaboloidClipInvMatrix)) * n);
		//intersec.emission = vec3(0);
		intersec.color = vec3(0.0, 1.0, 0.0);
		intersec.type = COAT;
	}
	
        
	return t;
	
} // end float SceneIntersect( Ray r, inout Intersection intersec )


//---------------------------------------------------------------------------
vec3 CalculateRadiance( Ray r, inout uvec2 seed, inout bool rayHitIsDynamic )
//---------------------------------------------------------------------------
{
	Intersection intersec;
	Sphere lightChoice;
	Ray firstRay;

	vec3 accumCol = vec3(0);
        vec3 mask = vec3(1);
	vec3 firstMask = vec3(1);
	vec3 checkCol0 = vec3(1);
	vec3 checkCol1 = vec3(0.5);
	vec3 dirToLight;
	vec3 tdir;
	vec3 n, nl, x;
        
	float nc, nt, Re, Tr;
	float weight;
	float randChoose;
	float diffuseColorBleeding = 0.1; // range: 0.0 - 0.5, amount of color bleeding between surfaces

	int diffuseCount = 0;

	bool bounceIsSpecular = true;
	bool sampleLight = false;
	bool firstTypeWasREFR = false;
	bool reflectionTime = false;
	bool firstTypeWasDIFF = false;
	bool shadowTime = false;

	
	for (int bounces = 0; bounces < 5; bounces++)
	{

		float t = SceneIntersect(r, intersec);

		if (intersec.type == CHECK || intersec.type == COAT || intersec.type == DIFF)
			rayHitIsDynamic = false;
		
		/*
		//not used in this scene because we are inside a huge sphere - no rays can escape
		if (t == INFINITY)
		{
                        break;
		}
		*/
		
		if (intersec.type == LIGHT)
		{	
			if (firstTypeWasREFR)
			{
				if (!reflectionTime) 
				{
					if (bounceIsSpecular || sampleLight)
						accumCol = mask * intersec.emission;
					
					// start back at the refractive surface, but this time follow reflective branch
					r = firstRay;
					mask = firstMask;
					// set/reset variables
					reflectionTime = true;
					bounceIsSpecular = true;
					sampleLight = false;
					// continue with the reflection ray
					continue;
				}
				else
				{
					accumCol += mask * intersec.emission; // add reflective result to the refractive result (if any)
					break;
				}	
			}

			if (firstTypeWasDIFF)
			{
				if (!shadowTime) 
				{
					if (sampleLight)
						accumCol = mask * intersec.emission * 0.5;
					
					// start back at the diffuse surface, but this time follow shadow ray branch
					r = firstRay;
					mask = firstMask;
					// set/reset variables
					shadowTime = true;
					bounceIsSpecular = false;
					sampleLight = true;
					// continue with the shadow ray
					continue;
				}
				else
				{
					accumCol += mask * intersec.emission * 0.5; // add shadow ray result to the colorbleed result (if any)
					break;
				}		
			}
			else if (bounceIsSpecular || sampleLight)
				accumCol = mask * intersec.emission; // looking directly at light or through a reflection
				
			// reached a light, so we can exit
			break;
		} // end if (intersec.type == LIGHT)


		// if we get here and sampleLight is still true, shadow ray failed to find a light source
		if (sampleLight) 
		{
			if (firstTypeWasREFR && !reflectionTime) 
			{
				// start back at the refractive surface, but this time follow reflective branch
				r = firstRay;
				mask = firstMask;
				// set/reset variables
				reflectionTime = true;
				bounceIsSpecular = true;
				sampleLight = false;
				// continue with the reflection ray
				continue;
			}

			if (firstTypeWasDIFF && !shadowTime) 
			{
				// start back at the diffuse surface, but this time follow shadow ray branch
				r = firstRay;
				mask = firstMask;
				// set/reset variables
				shadowTime = true;
				bounceIsSpecular = false;
				sampleLight = true;
				// continue with the shadow ray
				continue;
			}

			// nothing left to calculate, so exit	
			//break;
		}


		// useful data 
		n = intersec.normal;
                nl = dot(n, r.direction) < 0.0 ? normalize(n) : normalize(-n);
		x = r.origin + r.direction * t;

		randChoose = rand(seed) * 3.0; // 3 lights to choose from
		lightChoice = spheres[int(randChoose)];

		    
                if (intersec.type == DIFF || intersec.type == CHECK) // Ideal DIFFUSE reflection
		{
			diffuseCount++;

			if( intersec.type == CHECK )
			{
				float q = clamp( mod( dot( floor(x.xz * 0.04), vec2(1.0) ), 2.0 ) , 0.0, 1.0 );
				intersec.color = checkCol0 * q + checkCol1 * (1.0 - q);	
			}

			mask *= intersec.color;

			bounceIsSpecular = false;

			if (!firstTypeWasREFR && diffuseCount == 1)
			{	
				// save intersection data for future shadowray trace
				firstTypeWasDIFF = true;
				weight = sampleSphereLight(x, nl, dirToLight, lightChoice, seed);
				firstMask = mask * weight;
                                firstRay = Ray( x, dirToLight ); // create shadow ray pointed towards light
				firstRay.origin += nl * uEPS_intersect;

				// choose random Diffuse sample vector
				r = Ray( x, randomCosWeightedDirectionInHemisphere(nl, seed) );
				r.origin += nl * uEPS_intersect;
				continue;
			}
                        else
                        {
				weight = sampleSphereLight(x, nl, dirToLight, lightChoice, seed);
				mask *= clamp(weight, 0.0, 1.0);

                                r = Ray( x, dirToLight );
				r.origin += nl * uEPS_intersect;

				sampleLight = true;
				continue;
                        }
		} // end if (intersec.type == DIFF)
		
		if (intersec.type == SPEC)  // Ideal SPECULAR reflection
		{
			mask *= intersec.color;

			r = Ray( x, reflect(r.direction, nl) );
			r.origin += nl * uEPS_intersect;

			//bounceIsSpecular = true; // turn on mirror caustics
			continue;
		}
		
		if (intersec.type == REFR)  // Ideal dielectric REFRACTION
		{
			nc = 1.0; // IOR of Air
			nt = 1.5; // IOR of common Glass
			Re = calcFresnelReflectance(n, nl, r.direction, nc, nt, tdir);
			Tr = 1.0 - Re;

			if (bounces == 0)
			{	
				// save intersection data for future reflection trace
				firstTypeWasREFR = true;
				firstMask = mask * Re;
				firstRay = Ray( x, reflect(r.direction, nl) ); // create reflection ray from surface
				firstRay.origin += nl * uEPS_intersect;
				mask *= Tr;
			}
			else if (rand(seed) < Re)
			{
				r = Ray( x, reflect(r.direction, nl) ); // reflect ray from surface
				r.origin += nl * uEPS_intersect;
				continue;
			}

			// transmit ray through surface
			r = Ray(x, tdir);
			r.origin -= nl * uEPS_intersect;

			if (shadowTime)
			{
				mask = intersec.color;
				mask *= Tr * 0.3;
				sampleLight = true; // turn on refracting caustics
			}
			else
				mask *= intersec.color;
				
			continue;
			
		} // end if (intersec.type == REFR)
		
		if (intersec.type == COAT)  // Diffuse object underneath with ClearCoat on top
		{
			nc = 1.0; // IOR of Air
			nt = 1.4; // IOR of Clear Coat
			Re = calcFresnelReflectance(n, nl, r.direction, nc, nt, tdir);
			Tr = 1.0 - Re;

			// clearCoat counts as refractive surface
			if (bounces == 0)
			{	
				// save intersection data for future reflection trace
				firstTypeWasREFR = true;
				firstMask = mask * Re;
				firstRay = Ray( x, reflect(r.direction, nl) ); // create reflection ray from surface
				firstRay.origin += nl * uEPS_intersect;
				mask *= Tr;
			}
			else if (rand(seed) < Re)
			{
				r = Ray( x, reflect(r.direction, nl) ); // reflect ray from surface
				r.origin += nl * uEPS_intersect;
				continue;
			}
			
			diffuseCount++;

			mask *= intersec.color;
			
			bounceIsSpecular = false;

			if (diffuseCount == 1 && rand(seed) < diffuseColorBleeding)
                        {
                                // choose random Diffuse sample vector
				r = Ray( x, randomCosWeightedDirectionInHemisphere(nl, seed) );
				r.origin += nl * uEPS_intersect;
				continue;
                        }
                        else
                        {
				weight = sampleSphereLight(x, nl, dirToLight, lightChoice, seed);
				mask *= clamp(weight, 0.0, 1.0);
				
                                r = Ray( x, dirToLight );
				r.origin += nl * uEPS_intersect;

				sampleLight = true;
				continue;
                        }
			
		} //end if (intersec.type == COAT)
		
	} // end for (int bounces = 0; bounces < 5; bounces++)
	
	return accumCol;      
} // end vec3 CalculateRadiance( Ray r, inout uvec2 seed )



//-----------------------------------------------------------------------
void SetupScene(void)
//-----------------------------------------------------------------------
{
	vec3 z  = vec3(0.0);          
	vec3 L1 = vec3(1.0, 1.0, 1.0) * 18.0;// White light
	vec3 L2 = vec3(1.0, 0.8, 0.2) * 15.0;// Yellow light
	vec3 L3 = vec3(0.1, 0.7, 1.0) * 10.0;// Blue light
		
        spheres[0] = Sphere(150.0, vec3(-400, 900, 200), L1, z, LIGHT);//spherical white Light1 
	spheres[1] = Sphere(100.0, vec3( 300, 400,-300), L2, z, LIGHT);//spherical yellow Light2
	spheres[2] = Sphere( 50.0, vec3( 500, 250,-100), L3, z, LIGHT);//spherical blue Light3
	
	spheres[3] = Sphere(1000.0, vec3(  0.0, 1000.0,  0.0), z, vec3(1.0, 1.0, 1.0), CHECK);//Checkered Floor
        
}


//#include <pathtracing_main>

// tentFilter from Peter Shirley's 'Realistic Ray Tracing (2nd Edition)' book, pg. 60		
float tentFilter(float x)
{
	if (x < 0.5) 
		return sqrt(2.0 * x) - 1.0;
	else return 1.0 - sqrt(2.0 - (2.0 * x));
}

void main( void )
{
	// not needed, three.js has a built-in uniform named cameraPosition
	//vec3 camPos   = vec3( uCameraMatrix[3][0],  uCameraMatrix[3][1],  uCameraMatrix[3][2]);
	
	vec3 camRight   = vec3( uCameraMatrix[0][0],  uCameraMatrix[0][1],  uCameraMatrix[0][2]);
	vec3 camUp      = vec3( uCameraMatrix[1][0],  uCameraMatrix[1][1],  uCameraMatrix[1][2]);
	vec3 camForward = vec3(-uCameraMatrix[2][0], -uCameraMatrix[2][1], -uCameraMatrix[2][2]);
	
	// seed for rand(seed) function
	uvec2 seed = uvec2(uFrameCounter, uFrameCounter + 1.0) * uvec2(gl_FragCoord);

	vec2 pixelPos = vec2(0);
	vec2 pixelOffset = vec2(0);
	
	float x = rand(seed);
	float y = rand(seed);

	//if (!uCameraIsMoving)
	{
		pixelOffset.x = tentFilter(x);
		pixelOffset.y = tentFilter(y);
	}
	
	// pixelOffset ranges from -1.0 to +1.0, so only need to divide by half resolution
	pixelOffset /= (uResolution * 1.0); // normally this is * 0.5, but for dynamic scenes, * 1.0 looks sharper

	// we must map pixelPos into the range -1.0 to +1.0
	pixelPos = (gl_FragCoord.xy / uResolution) * 2.0 - 1.0;
	pixelPos += pixelOffset;

	vec3 rayDir = normalize( pixelPos.x * camRight * uULen + pixelPos.y * camUp * uVLen + camForward );
	
	// depth of field
	vec3 focalPoint = uFocusDistance * rayDir;
	float randomAngle = rand(seed) * TWO_PI; // pick random point on aperture
	float randomRadius = rand(seed) * uApertureSize;
	vec3  randomAperturePos = ( cos(randomAngle) * camRight + sin(randomAngle) * camUp ) * randomRadius;
	// point on aperture to focal point
	vec3 finalRayDir = normalize(focalPoint - randomAperturePos);
	
	Ray ray = Ray( cameraPosition + randomAperturePos, finalRayDir );

	SetupScene(); 

	bool rayHitIsDynamic = true;
	
	// perform path tracing and get resulting pixel color
	vec3 pixelColor = CalculateRadiance( ray, seed, rayHitIsDynamic );
	
	vec4 previousImage = texelFetch(tPreviousTexture, ivec2(gl_FragCoord.xy), 0);
	vec3 previousColor = previousImage.rgb;

	if (uCameraIsMoving)
	{
                previousColor *= 0.5; // motion-blur trail amount (old image)
                pixelColor *= 0.5; // brightness of new image (noisy)
        }
	else if (previousImage.a > 0.1)
	{
                previousColor *= 0.8; // motion-blur trail amount (old image)
                pixelColor *= 0.2; // brightness of new image (noisy)
        }
	else
	{
                previousColor *= 0.94; // motion-blur trail amount (old image)
                pixelColor *= 0.06; // brightness of new image (noisy)
        }
	
        out_FragColor = vec4( pixelColor + previousColor, rayHitIsDynamic? 1.0 : 0.0 );	
}
