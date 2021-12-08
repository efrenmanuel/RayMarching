gcc -o Debug\RayMarching.exe main.c -lgdi32 -lopengl32
copy fragment.glsl Debug\fragment.glsl
copy vertex.glsl Debug\vertex.glsl
Debug\RayMarching.exe