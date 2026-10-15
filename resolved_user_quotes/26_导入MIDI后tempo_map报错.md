# 用户原话
- 在某个特定的几个mid文件加载后,在轨道面板里移动或者切换到轨道面板会有:
  E 0:01:39:564   arrangement_lane.gd:297 @ _draw_tempo_map(): Invalid polygon data, triangulation failed.
  <C++ 错误>      Condition "indices.is_empty()" is true.
  <C++ 源文件>     servers/rendering/renderer_canvas_cull.cpp:1713 @ canvas_item_add_polygon()
  <栈追踪>         arrangement_lane.gd:297 @ _draw_tempo_map()
                arrangement_lane.gd:230 @ _draw()
