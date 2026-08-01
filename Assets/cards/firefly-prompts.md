# Firefly Text-to-Vector プロンプト集（花札 48 枚）

旧 Koikoi (`Dropbox/Codes/Koikoi/Assets/Sprites/Cards/{月:02d}-{連番:02d}.jpg`) の
伝統構図を、モダンフラットに再解釈して生成するためのプロンプト。

## 使い方

1. https://firefly.adobe.com → 生成 → **ベクター（Text to vector）**
2. 縦横比は **縦（3:4 か 9:16）**。実カード比 5.4:8.7 へは後段のフレーム合成で吸収する
3. プロンプトは「**共通スタイル文 + 札ごとの主題文**」を連結して貼る
4. 良い 1 枚が出たら**そのシード / スタイル設定を固定**して残りを量産（4 案から選ぶ）
5. SVG でダウンロード → `Assets/cards/` に配置 → フレーム（角丸・墨枠・紙面）は
   こちらのラッパースクリプトで統一合成する（生成物はアートワークのみでよい）

## 共通スタイル文（毎回末尾に付ける）

```
Modern flat vector illustration, minimalist, smooth rounded organic shapes,
bold solid colors, palette of charcoal, vermilion red, burnt orange, cream,
sage green and deep indigo, rich saturated hues, strong contrast between
light and dark shapes, crisp clean color separation,
no outlines, no gradients, no pastel tones, no desaturated colors,
one large cream blob shape behind the subject, a small dark navy ellipse
as ground shadow beneath the subject, generous negative space,
plain solid light background, centered vertical composition,
no text, no letters, no typography, no border, no frame
```

※ 文字（書・寿の字など）は Firefly が崩すので入れない。短冊はすべて無地リボンで表現。
※ くすみ対策: "muted"・"matte" は入れない（ベージュ×セージに寄る）。彩度は
   "vivid highly saturated"、コントラストは "strong contrast between light and
   dark shapes" で指定する。それでも淡く出る場合は主題文の色名を強める
   （例: "bright vermilion red plum blossoms" のように色を主題側にも書く）。

## 札ごとの主題文

| id | 旧スプライト | 札 | 主題文（プロンプト先頭に置く） |
|---|---|---|---|
| 0 | 01-01 | 松に鶴（光） | A white red-crowned crane standing upright in front of a large rising sun disc, stylized dark green pine needle clusters at the bottom corners. |
| 1 | 01-02 | 松に赤短 | A stylized dark green pine tree with a plain vermilion vertical ribbon hanging on one side. |
| 2 | 01-03 | 松のカス１ | A stylized dark green pine tree with layered needle clusters. |
| 3 | 01-04 | 松のカス２ | A stylized dark green pine tree with layered needle clusters, mirrored composition. |
| 4 | 02-01 | 梅に鶯（種） | A small round olive-green bush warbler perched on a blossoming red plum branch. |
| 5 | 02-02 | 梅に赤短 | A blossoming red plum branch with a plain vermilion vertical ribbon hanging beside it. |
| 6 | 02-03 | 梅のカス１ | A blossoming red plum branch with round red blossoms. |
| 7 | 02-04 | 梅のカス２ | A blossoming red plum branch with round red blossoms, mirrored composition. |
| 8 | 03-01 | 桜に幕（光） | A cherry tree in full bloom above a striped ceremonial curtain. |
| 9 | 03-02 | 桜に赤短 | Cherry blossom branches with a plain vermilion vertical ribbon. |
| 10 | 03-03 | 桜のカス１ | Cherry blossom branches full of soft pink blossoms. |
| 11 | 03-04 | 桜のカス２ | Cherry blossom branches full of soft pink blossoms, mirrored composition. |
| 12 | 04-01 | 藤に不如帰（種） | A little cuckoo bird flying across a crescent moon, purple wisteria clusters hanging from above. |
| 13 | 04-02 | 藤に短冊 | Hanging purple wisteria flower clusters with a plain vermilion vertical ribbon. |
| 14 | 04-03 | 藤のカス１ | Hanging purple wisteria flower clusters with green leaves. |
| 15 | 04-04 | 藤のカス２ | Hanging purple wisteria flower clusters with green leaves, mirrored composition. |
| 16 | 05-01 | 菖蒲に八橋（種） | Purple iris flowers beside a stylized zigzag wooden plank bridge. |
| 17 | 05-02 | 菖蒲に短冊 | Purple iris flowers with tall leaves and a plain vermilion vertical ribbon. |
| 18 | 05-03 | 菖蒲のカス１ | Purple iris flowers with tall green sword-shaped leaves. |
| 19 | 05-04 | 菖蒲のカス２ | Purple iris flowers with tall green sword-shaped leaves, mirrored composition. |
| 20 | 06-01 | 牡丹に蝶（種） | A butterfly with spread wings hovering above a large red peony flower. |
| 21 | 06-02 | 牡丹に青短 | A large red peony flower with a plain deep indigo vertical ribbon. |
| 22 | 06-03 | 牡丹のカス１ | Large red peony flowers with dark green leaves. |
| 23 | 06-04 | 牡丹のカス２ | Large red peony flowers with dark green leaves, mirrored composition. |
| 24 | 07-01 | 萩に猪（種） | A wild boar walking through arching pink bush clover branches. |
| 25 | 07-02 | 萩に短冊 | Arching pink bush clover branches with a plain vermilion vertical ribbon. |
| 26 | 07-03 | 萩のカス１ | Arching pink bush clover branches with small blossoms. |
| 27 | 07-04 | 萩のカス２ | Arching pink bush clover branches with small blossoms, mirrored composition. |
| 28 | 08-01 | 芒に月（光） | A huge pale full moon rising over a dark rounded hill of silver pampas grass, minimal sky. |
| 29 | 08-02 | 芒に雁（種） | Three wild geese flying in formation above a hill of silver pampas grass. |
| 30 | 08-03 | 芒のカス１ | A rounded hill covered with swaying silver pampas grass under an open sky. |
| 31 | 08-04 | 芒のカス２ | A rounded hill covered with swaying silver pampas grass, mirrored composition. |
| 32 | 09-01 | 菊に盃（種） | A plain red sake cup floating beside yellow chrysanthemum flowers. |
| 33 | 09-02 | 菊に青短 | Yellow chrysanthemum flowers with a plain deep indigo vertical ribbon. |
| 34 | 09-03 | 菊のカス１ | Yellow and white chrysanthemum flowers with green leaves. |
| 35 | 09-04 | 菊のカス２ | Yellow and white chrysanthemum flowers with green leaves, mirrored composition. |
| 36 | 10-01 | 紅葉に鹿（種） | A standing deer looking back over its shoulder among red maple branches. |
| 37 | 10-02 | 紅葉に青短 | Red maple branches with a plain deep indigo vertical ribbon. |
| 38 | 10-03 | 紅葉のカス１ | Red and orange maple leaves drifting on branches. |
| 39 | 10-04 | 紅葉のカス２ | Red and orange maple leaves drifting on branches, mirrored composition. |
| 40 | 11-01 | 柳に小野道風（光） | A courtier in a red robe holding an umbrella beside a stream, watching a small frog leap toward a drooping willow branch, thin diagonal rain lines. |
| 41 | 11-02 | 柳に燕（種） | A swallow flying between drooping willow branches. |
| 42 | 11-03 | 柳に短冊 | Drooping willow branches with a plain vermilion vertical ribbon. |
| 43 | 11-04 | 柳のカス | An abstract storm motif: dark swirling clouds, stylized lightning shapes and diagonal rain over a drum silhouette. |
| 44 | 12-01 | 桐に鳳凰（光） | A mythical phoenix with sweeping tail feathers flying above large paulownia leaves. |
| 45 | 12-02 | 桐のカス１ | Stylized paulownia leaves with upright flower buds. |
| 46 | 12-03 | 桐のカス２ | Stylized paulownia leaves with upright flower buds, mirrored composition. |
| 47 | 12-04 | 桐のカス３ | Stylized paulownia leaves with upright yellow flower buds and a yellow accent band. |
