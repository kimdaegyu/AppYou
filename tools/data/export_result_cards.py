"""Build public result PNGs from the pilot bundle and approved art. Requires Pillow."""
import json
from pathlib import Path
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

APP = Path(__file__).resolve().parents[2] / "app"
BUNDLE = APP / "assets/data/0.9.0/preview"
ART = APP / "assets/images/life_tactics"
OUT = APP / "web/result-cards"
CREAM = "#fff9f2"
INK = "#4a2e1e"
FONTS = {
    "ko": "pretendard/PretendardVariable.ttf",
    "ja": "pretendard_jp/PretendardJPVariable.ttf",
    "en": "pretendard_std/PretendardStdVariable.ttf",
    "pt-BR": "pretendard_std/PretendardStdVariable.ttf",
}


@lru_cache
def font(locale, size, weight):
    face = ImageFont.truetype(str(APP / "assets/fonts" / FONTS[locale]), size)
    face.set_variation_by_axes([weight])
    return face


def lines(text, face, limit):
    rows = []
    for word in text.split():
        if rows and face.getlength(rows[-1] + " " + word) <= limit:
            rows[-1] += " " + word
            continue
        rows.append("")
        for char in word:
            if rows[-1] and face.getlength(rows[-1] + char) > limit:
                rows.append("")
            rows[-1] += char
    return rows


def contain(canvas, path, box):
    x, y, width, height = box
    with Image.open(path) as source:
        layer = ImageOps.contain(source.convert("RGBA"), (width, height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(layer, (round(x+(width-layer.width)/2), round(y+(height-layer.height)/2)))


def render(quiz, result, lang, strings):
    result_id = result["resultTypeId"]
    blocks = []
    y = 670
    for key, size, weight, color in [
        ("nameTextKey",72,800,INK), ("catchphraseKey",42,700,"#a44b12"), ("descriptionKey",36,500,INK)
    ]:
        face = font(lang,size,weight)
        for line in lines(strings[result[key]], face, 928):
            blocks.append((y,line,face,color))
            y += round(size*1.25)
        y += 18
    height = max(1080,y+92)
    canvas = Image.new("RGBA",(1080,height),CREAM)
    frame = Image.open(ART/"share_template_v001.png").convert("RGBA").resize((1080,1080))
    if height > 1080:
        frame = frame.resize((1080,height))
    canvas.alpha_composite(frame)
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((48,120,1028,max(630,round(630*height/1080))),fill=CREAM)
    stadium = ImageOps.fit(Image.open(ART/"stadium_v001.webp").convert("RGB"),(1008,492)).filter(ImageFilter.GaussianBlur(9))
    mask = Image.new("L",stadium.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,1007,491),radius=30,fill=255)
    canvas.paste(stadium,(36,168),mask)
    saida = max((APP/"assets/images/saida").glob(f"saida_life_tactics_{result_id}_v*.webp"))
    contain(canvas,saida,(60,215,440,440))
    contain(canvas,ART/"tactics_board_v002.webp",(680,220,344,430))
    counts = list(map(int,result["formation"].split("-")))[::-1]
    dimensions = {d["dimensionId"]:strings[d["nameTextKey"]] for d in quiz["dimensions"]}
    for row,(count,dimension) in enumerate(zip(counts,["richness","meaning","happiness"])):
        center = 220+430*(0.08+(1-0.08-0.093)*(row+0.5)/3)
        label=dimensions[dimension]
        size=32
        while font(lang,size,600).getlength(label)>180:
            size-=1
        draw.text((668,center),label,font=font(lang,size,600),fill=INK,anchor="rm")
        marker=46
        gap=(344-count*marker)/(count+1)
        for i in range(count):
            contain(canvas,ART/"jersey_marker_v001.webp",(680+gap+i*(gap+marker),center-marker/2,marker,marker))
    def title(x,y,text,size,weight,color,anchor):
        draw.text((x,y),text,font=font(lang,size,weight),fill=color,anchor=anchor)
    title(76,49,strings["life_tactics.pilot.cardBrand"],54,800,INK,"lt")
    title(1004,56,strings[quiz["titleTextKey"]],36,600,"#8b5b3a","rt")
    title(1004,116,strings["life_tactics.result.formationTitle"].replace("{formation}",result["formation"]),36,700,INK,"rt")
    for top,text,face,color in blocks:
        draw.text((76,top),text,font=face,fill=color,anchor="lt")
    title(76,height-35,strings["life_tactics.pilot.cardStudio"],33,600,"#8b5b3a","lb")
    canvas.convert("RGB").save(OUT/f"look-at-you_life-tactics_{result_id}_{lang}.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    quiz = json.loads((BUNDLE/"quizzes/life_tactics.json").read_bytes())
    ko = json.loads((BUNDLE/"locales/ko.json").read_bytes())["strings"]
    for lang in FONTS:
        strings = ko | json.loads((BUNDLE/f"locales/{lang}.json").read_bytes())["strings"]
        for result in quiz["resultTypes"]:
            render(quiz,result,lang,strings)
