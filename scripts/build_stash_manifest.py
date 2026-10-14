"""Translate the supplied Stash CSS keyframes/atlas rectangles into native data.

No artwork is redrawn. Run from the repo root before build_stash_portraits.swift.
"""
from pathlib import Path
import ast
import json
import re

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / "docs/mascot/Main.dc.html").read_text()
css = re.search(r"<style>(.*?)</style>", html, re.S)[1]
css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
rows = ast.literal_eval("[" + html.split("const rows = [", 1)[1].split("];", 1)[0].replace("null", "None") + "]")
parts = json.loads(html.split("const PARTS = ", 1)[1].split(";", 1)[0])

def declarations(source):
    return dict(item.strip().split(":", 1) for item in source.split(";") if ":" in item)

def transform(source):
    values = [0, 0, 1, 1, 0, 0, 0]
    order = []
    for name, args in re.findall(r"(\w+)\(([^)]+)\)", source):
        nums = [float(x) for x in re.findall(r"-?(?:\d*\.)?\d+", args)]
        if name.startswith("translate"):
            op = "translate"
            if name == "translateX": values[0] = nums[0]
            elif name == "translateY": values[1] = nums[0]
            else: values[:2] = [nums[0], nums[1] if len(nums) > 1 else 0]
        elif name.startswith("scale"):
            op = "scale"
            if name == "scaleX": values[2] = nums[0]
            elif name == "scaleY": values[3] = nums[0]
            else: values[2:4] = [nums[0], nums[1] if len(nums) > 1 else nums[0]]
        elif name == "rotate": op = name; values[4] = nums[0]
        elif name == "skewX": op = name; values[5] = nums[0]
        elif name == "skewY": op = name; values[6] = nums[0]
        else: raise ValueError(f"Unsupported transform: {name}")
        if op not in order: order.append(op)
    return values, order

animations = {}
plain_css = css
for match in list(re.finditer(r"@keyframes\s+(\w+)\s*\{", css)):
    start = match.end()
    depth, end = 1, start
    while depth:
        depth += (css[end] == "{") - (css[end] == "}")
        end += 1
    block = css[start:end-1]
    animation = {"order": [], "transforms": [], "opacities": []}
    for times, rules in re.findall(r"([\d%,\s.]+)\{([^}]+)\}", block):
        props = declarations(rules)
        for time in re.findall(r"([\d.]+)%", times):
            t = float(time) / 100
            if "transform" in props:
                values, order = transform(props["transform"])
                animation["transforms"].append({"t": t, "values": values})
                for operation in order:
                    if operation not in animation["order"]: animation["order"].append(operation)
            if "opacity" in props:
                animation["opacities"].append({"t": t, "value": float(props["opacity"])})
    for field in ("transforms", "opacities"):
        animation[field].sort(key=lambda frame: frame["t"])
    animations[match[1]] = animation
    plain_css = plain_css.replace(css[match.start():end], "")

rules = [(selector.strip(), declarations(body))
         for selectors, body in re.findall(r"([^{}]+)\{([^{}]*)\}", plain_css)
         for selector in selectors.split(",")]

def binding(key, target, duration, delay=0, fx=False):
    classes = {"cell", "a-"+key, "anim", target}
    if fx: classes.add("fxp")
    style = {}
    for selector, properties in rules:
        required = set(re.findall(r"\.([\w-]+)", selector))
        if required and required.issubset(classes): style.update(properties)
    def seconds(property, fallback):
        m = re.search(r"(-?[\d.]+)s", style.get(property, ""))
        return float(m[1]) if m else fallback
    name = style.get("animation-name")
    assert name is None or name in animations, name
    return {"animation": name, "duration": seconds("animation-duration", duration),
            "delay": seconds("animation-delay", delay),
            "linear": style.get("animation-timing-function") == "linear"}

poses = []
for key, name, context, duration_label, crop, shadow in rows:
    duration = float(duration_label.split()[0])
    fx_index = 0
    layers = []
    for part_name, is_fx, x, y, w, h, ax, ay in parts.get(key, []):
        delay = -0.22 * fx_index if is_fx else 0
        fx_index += is_fx
        layers.append({"name": part_name, "atlas": "effects" if is_fx else "parts",
                       "crop": [x,y,w,h], "anchor": [ax/100,ay/100],
                       "motion": binding(key, "p-"+part_name, duration, delay, bool(is_fx))})
    if shadow: shadow = [shadow[0]-2,shadow[1]-2,shadow[2]+4,shadow[3]+4]
    poses.append({"key": key, "name": name, "duration": duration, "crop": crop,
                  "shadow": shadow, "bodyMotion": binding(key, "body", duration),
                  "shadowMotion": binding(key, "sh", duration), "parts": layers})

manifest = {"atlases": {"body": "e8b35306c9f0310f14a9cbfbb6a22773",
                         "parts": "bbb03860f5392c103323ee7a3c040045",
                         "effects": "688192c2e6e5653d31a2352393c1e0b9",
                         "shadow": "fa28d32e56a095e8e8b56e017e175b19"},
            "poses": poses, "animations": animations}
out = ROOT / "ios/ExpenseTracker/Resources/Stash/stash-animation.json"
out.write_text(json.dumps(manifest, indent=2)+"\n")
print(f"Wrote {len(poses)} poses and {len(animations)} native keyframe tracks: {out}")
