# Writes the retarget import settings into a .glb.import (game copy of lookdev/tools/patch_import.py).
# Usage: python -I patch_import.py <file.glb.import> <skeleton node path> <bonemap.tres>
import sys
p, skel, bm = sys.argv[1], sys.argv[2], sys.argv[3]
sub = '''_subresources={
"nodes": {
"PATH:%s": {
"retarget/bone_map": Resource("res://assets/characters/anime/retarget/%s"),
"retarget/bone_renamer/rename_bones": true,
"retarget/bone_renamer/unique_node/make_unique": true,
"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",
"retarget/remove_tracks/unmapped_bones": true,
"retarget/rest_fixer/apply_node_transforms": true,
"retarget/rest_fixer/fix_silhouette/enable": true,
"retarget/rest_fixer/normalize_position_tracks": true,
"retarget/rest_fixer/overwrite_axis": true
}
}
}''' % (skel, bm)
s = open(p).read()
s = s.replace('_subresources={}', sub).replace('gltf/embedded_image_handling=1', 'gltf/embedded_image_handling=3')
open(p, 'w').write(s)
