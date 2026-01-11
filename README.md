# Map-Gen

## This is intended as a tool for testing and visualizing:
* Procedural Map Gen Algorithms
* Pathfinding Algorithms

libraries used:
[raylib-zig](https://github.com/raylib-zig/raylib-zig): modified slightly to work with zig v0.16.0.

Other resources:
[Roguelike Celebration: Herbert Wolverson - Procedural Map Generation Techniques](https://www.youtube.com/watch?v=TlLIOgWYVpI): Pretty much all map gen techniques planned are discussed in the video.

[Computerphile: Dijkstra's Algorithm](https://www.youtube.com/watch?v=GazC3A4OQTE)
[Computerphile: A* Search Algorithm](https://www.youtube.com/watch?v=ySN5Wnu88nE)

### Progress
#### Map Generation
* [x] Cellular Automata
* [ ] Simple Rooms
* [ ] BSP Rooms
* [ ] Drunkard's Walk
* [ ] Diffusion Aggregation
* [ ] Voronoi Diagrams
* [ ] Perlin/Simplex Noise

Note: A checkbox does not indicate customizable, simply that it is an enabled option to test with defaults. Once all features are fully customizable this note will disappear.

#### Pathfinding
* [x] Depth First Search
* [x] Breadth First Search
* [x] Dijkstra
* [x] A-Star

#### Customizability
Currently there are options for:
* Walking or Flying (ignores "chasms")
* Orthogonal or +Diagonal Pathing 
* Pathing Algorithm (DFS, BFS, Dijkstra, A-Star)
* Toggle Dijkstra heatmap for mouse cursor
Coming Soon: Choosing Map Generation Algorithm

