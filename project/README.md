# weather-widget Project Overlay

このファイルは既存 `weather-widget` に追加したKiNoTch Project Overlayの入口です。利用者向けREADME、PWA資産、Domain実装はrootに残します。

## 概要

`weather-widget` は、既存のmanifest、service worker、静的assetで構成されたinstallable Web/PWAです。

- 個別情報・仕様・実装: project/
- 個別プロジェクト定義: project/project.json
- 個別仕様索引: project/docs/INDEX.md
- 現在状態: project/docs/CURRENT_STATE.md
- 共通操作: .kinotch/README_BASE.md

## 所有境界

- PWA manifest、service worker、icons、weather UI、offline policyはProject側の既存実装を正本とします。
- KiNoTch Baseはrepository構造、診断、verify入口を提供します。
- PWA Defaultは既存実装と競合するため `OVERRIDE` として記録します。

## 最短利用方法

```powershell
.\knt.cmd doctor
.\knt.cmd base-check
.\knt.cmd verify
```

既存の利用方法はroot READMEと静的assetを参照してください。
