// trace_cards.jsx — 旧 Koikoi のカード JPG を Illustrator の Image Trace で
// 一括ベクター化して SVG に書き出す。
//
// 実行方法: Scripts/trace_cards.sh を使う（open -a "Adobe Illustrator" でも可）。
// 入出力パスは下の定数を編集する。

// ---- 設定 -------------------------------------------------------------

// 入力は Scripts/pretrace_cards.py が紙テクスチャを除去した PNG
// （trace_cards.sh が生成する）
var INPUT_DIR = Folder("/tmp/koikoi_pretrace");
var OUTPUT_DIR = Folder("~/src/koikoi-swift/Assets/cards/traced");

// go-koikoi の札 ID (0-47) 順のスラッグ。
// 旧スプライト {月:02d}-{連番:02d}.jpg → id = (月-1)*4 + (連番-1)
var SLUGS = [
    "matsu_tsuru", "matsu_akatan", "matsu_kasu1", "matsu_kasu2",
    "ume_uguisu", "ume_akatan", "ume_kasu1", "ume_kasu2",
    "sakura_maku", "sakura_akatan", "sakura_kasu1", "sakura_kasu2",
    "fuji_hototogisu", "fuji_tanzaku", "fuji_kasu1", "fuji_kasu2",
    "ayame_yatsuhashi", "ayame_tanzaku", "ayame_kasu1", "ayame_kasu2",
    "botan_cho", "botan_aotan", "botan_kasu1", "botan_kasu2",
    "hagi_inoshishi", "hagi_tanzaku", "hagi_kasu1", "hagi_kasu2",
    "susuki_tsuki", "susuki_kari", "susuki_kasu1", "susuki_kasu2",
    "kiku_sakazuki", "kiku_aotan", "kiku_kasu1", "kiku_kasu2",
    "momiji_shika", "momiji_aotan", "momiji_kasu1", "momiji_kasu2",
    "yanagi_michikaze", "yanagi_tsubame", "yanagi_tanzaku", "yanagi_kasu",
    "kiri_hoo", "kiri_kasu1", "kiri_kasu2", "kiri_kasu3"
];

// ---- 本体 -------------------------------------------------------------

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

function logLine(file, text) {
    file.open("a");
    file.writeln(text);
    file.close();
}

function configureTracing(tracing) {
    var o = tracing.tracingOptions;
    // フルカラー（色数制限なし）。バージョンにより存在しない
    // プロパティがあるため個別に握りつぶす
    try { o.tracingMode = TracingModeType.TRACINGMODECOLOR; } catch (e1) {}
    try { o.tracingColorTypeValue = TracingColorType.TRACINGFULLCOLOR; } catch (e2) {}
    try { o.pathFidelity = 85; } catch (e3) {}
    try { o.cornerFidelity = 80; } catch (e4) {}
    try { o.noiseFidelity = 20; } catch (e5) {}
    try { o.ignoreWhite = false; } catch (e6) {}
}

function svgOptions() {
    var opts = new ExportOptionsSVG();
    opts.embedRasterImages = false;
    opts.coordinatePrecision = 2;
    opts.cssProperties = SVGCSSPropertyLocation.STYLEATTRIBUTES;
    opts.fontSubsetting = SVGFontSubsetting.None;
    opts.documentEncoding = SVGDocumentEncoding.UTF8;
    return opts;
}

function main() {
    if (!INPUT_DIR.exists) {
        alert("入力フォルダが見つかりません:\n" + INPUT_DIR.fsName);
        return;
    }
    if (!OUTPUT_DIR.exists) {
        OUTPUT_DIR.create();
    }

    var logFile = File(OUTPUT_DIR.fsName + "/trace_log.txt");
    logLine(logFile, "==== trace_cards start " + new Date() + " ====");

    var files = INPUT_DIR.getFiles("*.png");
    files.sort();

    var userInteraction = app.userInteractionLevel;
    app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;

    var done = 0;
    var failed = 0;

    for (var i = 0; i < files.length; i++) {
        var f = files[i];
        var base = f.name.replace(/\.png$/i, ""); // 例: "01-01"
        var parts = base.split("-");
        if (parts.length !== 2) {
            logLine(logFile, "SKIP (name): " + f.name);
            continue;
        }
        var month = parseInt(parts[0], 10);
        var index = parseInt(parts[1], 10);
        var id = (month - 1) * 4 + (index - 1);
        if (isNaN(id) || id < 0 || id > 47) {
            logLine(logFile, "SKIP (id): " + f.name);
            continue;
        }
        var outName = pad2(id) + "_" + SLUGS[id] + ".svg";
        var outFile = File(OUTPUT_DIR.fsName + "/" + outName);

        try {
            var doc = app.open(f);
            var item = doc.pageItems[0];
            // trace() は PluginItem を返し、トレース本体は .tracing (TracingObject)
            var pluginItem = item.trace();
            configureTracing(pluginItem.tracing);
            app.redraw(); // トレース結果を確定させる
            pluginItem.tracing.expandTracing();
            doc.exportFile(outFile, ExportType.SVG, svgOptions());
            doc.close(SaveOptions.DONOTSAVECHANGES);
            done++;
            logLine(logFile, "OK: " + f.name + " -> " + outName);
        } catch (err) {
            failed++;
            logLine(logFile, "FAIL: " + f.name + " : " + err);
            try { app.activeDocument.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {}
        }
    }

    app.userInteractionLevel = userInteraction;
    logLine(logFile, "==== done=" + done + " failed=" + failed + " ====");
    alert("Image Trace 一括処理 完了\n成功: " + done + " / 失敗: " + failed +
          "\n出力: " + OUTPUT_DIR.fsName + "\nログ: trace_log.txt");
}

main();
