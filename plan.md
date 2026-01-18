# SimpleDAW Next Steps (Do Not Edit Code Tonight)

## Context snapshot
- Panel switching exists (Envelope / Comment / 3D) with the switch button in the TopBar near Browser.
- Comment panel uses selection from the drag bar + "add" button to create comment boxes.
- 3D panel is a SubViewport with a cube and mouse interaction (rotate + zoom).
- Envelope drag bar now controls the shared panel frame height.

## Issues observed (from user)
1) Comment panel placement: new comments should always stack below the last comment, not only when overlap occurs.
2) Panel should have a right-side vertical scrollbar (matching the roll area style).
3) 3D panel sizing/clipping:
   - Should behave like a viewport crop, not stretch; if window is smaller, render only visible portion.
   - Max panel height should be based on 1280/720 aspect (height = width * 720 / 1280), so it shrinks as width shrinks.

## Plan (for tomorrow)
1) Fix comment stacking: always append a new comment to the next row, regardless of overlap; confirm row order and spacing behavior.
2) Add a right-side scrollbar for the panel frame; wire it to the panel content (envelope/comment/3D) and keep style consistent with existing scrollbars.
3) Update 3D panel viewport behavior:
   - Stop stretch; clamp/crop rendering to the visible viewport area.
   - Compute max panel height from current panel width using 1280/720 ratio.
4) Verify panel height interactions with the drag bar after the new max height logic.


开发者:我发现关于3D面板视口剪裁这个问题,其实横向的拉伸就是会导致一些剪裁的,这是我想象的纵向拉伸应该有的,不过摄像机中心和我想的不太一样,横向拉伸是剪裁两侧,而我要的纵向拉伸是剪裁上方的
