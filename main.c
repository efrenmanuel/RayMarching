//Copyright (c) 2011 <>< Charles Lohr - Under the MIT/x11 or NewBSD License you choose.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <errno.h>
#include "os_generic.h"

#include <direct.h>
#define GetCurrentDir _getcwd

#define CNFG3D
#define CNFG_IMPLEMENTATION
#define CNFGOGL

#include "CNFG.h"

unsigned frames = 0;
unsigned long iframeno = 0;


void HandleKey( int keycode, int bDown )
{
	if( keycode == 27 ) exit( 0 );
}

void HandleButton( int x, int y, int button, int bDown )
{
}

void HandleMotion( int x, int y, int mask )
{
}

#define HMX 40
#define HMY 40
short screenx, screeny;
float Heightmap[HMX*HMY];

void HandleDestroy()
{
	printf( "Destroying\n" );
	exit(10);
}

uint32_t randomtexturedata[65536];


unsigned long getFileLength(FILE* file)
{
	printf("Vertex: %s\n", file);
	fseek(file, 0, SEEK_END);
	unsigned long sz = ftell(file);

	fseek(file, 0, SEEK_SET);

	return sz;
}

int main()
{
	int i, x, y;
	double ThisTime;
	double LastFPSTime = OGGetAbsoluteTime();
	double LastFrameTime = OGGetAbsoluteTime();
	double SecToWait;
	int linesegs = 0;

	CNFGBGColor = 0x000000FF; //Darkblue
	CNFGSetup( "Ray Marching Test", 640, 480 );

	char buff[FILENAME_MAX]; //create string buffer to hold path
	GetCurrentDir(buff, FILENAME_MAX);

	FILE* vertexFile;
	fopen_s(&vertexFile, "vertex.glsl", "rb");

	char* vertexString = (char*)malloc(getFileLength(vertexFile) + 1);
	fread(vertexString, 1, getFileLength(vertexFile), vertexFile);
	fclose(vertexFile);

	FILE* fragmentFile;
	fopen_s(&fragmentFile, "fragment.glsl", "rb");

	char* fragmentString = (char*)malloc(getFileLength(fragmentFile) + 1);
	fread(fragmentString, 1, getFileLength(fragmentFile), fragmentFile);
	fclose(fragmentFile);

	GLuint shader = CNFGGLInternalLoadShader(vertexString, fragmentString);

	float vertices[] = {
		// positions         // colors
		 1.f, -1.f, 0.0f, //  1.0f, 0.0f, 0.0f,   // bottom right
		-1.f, -1.f, 0.0f, // 0.0f, 1.0f, 0.0f,   // bottom left
		 1.f,  1.f, 0.0f, // 0.0f, 0.0f, 1.0f    // top
		 1.f,  1.f, 0.0f,
		 -1.f, -1.f, 0.0f,
		 -1.f,  1.f, 0.0f
	};

	uint32_t colors[] = {
		// positions         // colors
		 1.0f, 0.0f, 0.0f,   // bottom right
		 0.0f, 1.0f, 0.0f,   // bottom left
		 0.0f, 0.0f, 1.0f,    // top 
		 1.0f, 0.0f, 0.0f,   // bottom right
		 0.0f, 1.0f, 0.0f,   // bottom left
		 0.0f, 0.0f, 1.0f,
	};

	printf("width : %d\n", HMX);

	while(1)
	{
		int i, pos;
		float f;
		iframeno++;
		RDPoint pto[3];

		CNFGHandleInput();

		CNFGClearFrame();
		CNFGColor( 0xFFFFFFFF );
		CNFGGetDimensions( &screenx, &screeny );

		CNFGglUniform2i(CNFGglGetUniformLocation(shader, "ScreenSize"), CNFGBufferx, CNFGBuffery);
		CNFGglUniform1f(CNFGglGetUniformLocation(shader, "time"), OGGetAbsoluteTime());
		glViewport(0, 0, screenx, screeny);
		CNFGEmitTriangles(shader, vertices, colors, 6);
		
		frames++;
		CNFGSwapBuffers();	

		ThisTime = OGGetAbsoluteTime();
		if( ThisTime > LastFPSTime + 1 )
		{
			printf( "FPS: %d\n", frames );
			frames = 0;
			linesegs = 0;
			LastFPSTime+=1;
		}

		SecToWait = .016 - (ThisTime - LastFrameTime); 
		LastFrameTime += .016;
		if( SecToWait > 0 )
			OGUSleep( (int)( SecToWait * 1000000 ) );
	}

	return(0);
}

