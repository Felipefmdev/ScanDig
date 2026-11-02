"""Observação QA explícita de dois scripts na snapshot; nunca executa engine.

Não altera fechamento, await, assert, FPS, time_scale ou process_mode.
Só chama apply_observation após a verificação integral da árvore CI original.
"""
import copy
import difflib
import json
from pathlib import Path

import linux_qa as qa

SHOP = 'ui/world_upgrade_shop.gd'
TEST = 'tests/unit/test_world_upgrade_shop.gd'
BASE_HASHES = {
    SHOP: 'E986718BB973637ED953D39E35E95D3F2FD816966C4674D9AE12DE88D63A2F93',
    TEST: '3DDBE9C3FD11CD3066456797B763B9830EF316C293577BDBF7967CF4E7C27253',
}
CASES = (
    'test_dead_actor_cannot_open_and_death_while_open_closes',
    'test_range_loss_closes_and_out_of_range_open_is_rejected',
    'test_counter_free_closes_without_retaining_invalid_reference',
    'test_current_scene_change_closes_even_if_old_counter_still_exists',
)


def once(text, before, after):
    if text.count(before) != 1:
        raise RuntimeError('Observation anchor is not unique: ' + before[:70])
    return text.replace(before, after, 1)


def instrument_shop(text):
    text = once(text, 'var _open: bool = false\n',
        'var _qa210_idle_count: int = 0\n'
        'var _qa210_close_count: int = 0\n'
        'var _qa210_open_count: int = 0\n'
        'var _qa210_last_branch: String = "never"\n'
        'var _open: bool = false\n')
    start = text.index('func _process(')
    end = text.index('\n\nfunc _input(', start)
    process = text[start:end]
    process = once(process, 'func _process(_delta: float) -> void:\n',
        'func _process(_delta: float) -> void:\n\t_qa210_idle_count += 1\n\t_qa210_last_branch = "entered"\n')
    process = once(process, '\tif not _open:\n', '\tif not _open:\n\t\t_qa210_last_branch = "already_closed"\n')
    for condition, label in (
        ('if get_tree().current_scene != _scene or not is_instance_valid(_counter) or not is_instance_valid(_actor):', 'scene_or_reference'),
        ('if not _valid_actor(_counter, _actor):', 'invalid_actor'),
        ('if PauseMenu.is_open() or VictoryScreen.is_open():', 'higher_modal'),
    ):
        process = once(process, '\t' + condition + '\n', '\t' + condition + '\n\t\t_qa210_last_branch = "' + label + '"\n')
    text = text[:start] + process + text[end:]
    text = once(text, '\t_open = true\n', '\t_open = true\n\t_qa210_open_count += 1\n')
    text = once(text, 'func close() -> void:\n', 'func close() -> void:\n\t_qa210_close_count += 1\n')
    return text


SNAPSHOT_HELPER = '''

## QA observation only. No await, asserts, mutation of scene/modal, or close/open calls.
func _qa210_snapshot() -> Dictionary:
	var counter_valid: bool = is_instance_valid(_counter)
	var actor_valid: bool = is_instance_valid(_actor)
	return {
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"shop_idle_count": int(_shop.get("_qa210_idle_count")),
		"shop_close_count": int(_shop.get("_qa210_close_count")),
		"shop_open_count": int(_shop.get("_qa210_open_count")),
		"shop_last_branch": str(_shop.get("_qa210_last_branch")),
		"shop_open": _is_open(),
		"actor_settings_open": _actor.is_settings_open() if actor_valid else false,
		"actor_health": _actor.health if actor_valid else -1.0,
		"actor_alive": _actor.is_alive() if actor_valid else false,
		"actor_downed": _actor.is_downed if actor_valid else false,
		"actor_valid": actor_valid,
		"counter_valid": counter_valid,
		"counter_in_range": _counter.is_actor_in_range(_actor) if counter_valid and actor_valid else false,
		"scene_matches_shop": get_tree().current_scene == _shop.get("_scene"),
		"shop_processing": _shop.is_processing(),
		"shop_can_process": _shop.can_process(),
		"shop_process_mode": _shop.process_mode,
		"tree_paused": get_tree().paused,
		"pause_modal_open": PauseMenu.is_open(),
		"victory_modal_open": VictoryScreen.is_open(),
	}
'''


def instrument_test(text):
    for name in CASES:
        start = text.index('func ' + name + '() -> void:\n')
        end = text.find('\n\nfunc ', start + 1)
        if end == -1:
            end = len(text)
        block = text[start:end]
        block = once(block, '\tawait wait_frames(3)\n',
            '\tvar qa210_before: Dictionary = _qa210_snapshot()\n'
            '\tawait wait_frames(3)\n'
            '\tvar qa210_after: Dictionary = _qa210_snapshot()\n')
        # Emit only AFTER all original asserts. Samples were taken before asserts.
        block = block.rstrip() + '\n\tprint("QA210_OBSERVATION " + JSON.stringify({"schema": "qa210-callback-v1", "test": "' + name + '", "before": qa210_before, "after": qa210_after}))\n'
        text = text[:start] + block + text[end:]
    return text.rstrip() + '\n' + SNAPSHOT_HELPER


def apply_observation(snapshot, evidence, source_path):
    sources = json.loads(source_path.read_text(encoding='utf-8'))
    if sources['tree'] != qa.TREE or qa.tree_id(sources['files']) != qa.TREE:
        raise RuntimeError('Original CI provenance required before instrumentation')
    manifest = copy.deepcopy(sources)
    records = {row['path']: row for row in manifest['files']}
    changes = []
    patch = []
    for name, transform in ((SHOP, instrument_shop), (TEST, instrument_test)):
        path = snapshot / name
        if qa.digest(path) != BASE_HASHES[name]:
            raise RuntimeError('Observation base hash mismatch: ' + name)
        before = path.read_text(encoding='utf-8')
        after = transform(before)
        path.write_text(after, encoding='utf-8', newline='\n')
        data = path.read_bytes()
        record = records[name]
        changes.append({'path': name, 'before_sha256': record['sha256'], 'after_sha256': qa.digest(path)})
        record.update(sha256=qa.digest(path), blob=qa.blob_id(data), size=len(data))
        patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
        target = evidence/'instrumented-sources'/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
    execution_tree = qa.tree_id(manifest['files'])
    if execution_tree != qa.OBSERVATION_TREE:
        raise RuntimeError('Instrumented tree differs from reviewed exact tree')
    manifest.update(tree=execution_tree, input_tree=qa.TREE, input_commit=qa.COMMIT,
                    execution_is_ci_identical=False, instrumentation=changes,
                    original_manifest_sha256=qa.digest(source_path))
    qa.save(evidence/'instrumented-sources-manifest.json',manifest)
    (evidence/'instrumented-sources.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
    return evidence/'instrumented-sources-manifest.json'
