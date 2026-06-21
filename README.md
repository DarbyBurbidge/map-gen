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

[Adrian's Soapbox](https://adrianb.io/2014/08/09/perlinnoise.html)

### Progress
#### Map Generation
* [x] Cellular Automata
* [ ] Simple Rooms
* [x] BSP Rooms
* [ ] Drunkard's Walk
* [ ] Diffusion Aggregation
* [x] Voronoi Diagrams (not walkable)
* [x] Perlin/Simplex Noise (not walkable)

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

#### On the Horizon
* Ability to customize algorithm parameters after selection
* Ability to drop a simple character in a map and walk around
* Ability to drop enemy NPCs into the map and then do a little test combat


