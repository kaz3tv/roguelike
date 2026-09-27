# 効果音・BGM のクレジットとライセンス

ここにある音はすべて **CC0 1.0（パブリックドメイン）** の素材です。
商用利用・改変・再配布が自由で、クレジット表記も不要です（ただし感謝を込めて、ゲームのクレジット画面に載せるのがおすすめです）。

- CC0 の条文：https://creativecommons.org/publicdomain/zero/1.0/deed.ja

## BGM（`bgm/`）

作曲：**Komiku**（Free Music Archive で公開、アルバムページに「CC0 1.0 Universal」と明記）

| ファイル | 使う場面 | 元の曲名 | 収録アルバム | 長さ |
| --- | --- | --- | --- | --- |
| `title.ogg` | タイトル画面 | Opening | [It's time for adventure! vol 4](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_4) | 2:01 |
| `dungeon_1.ogg` | 1〜3階 | Ancient Heavy Tech Donjon | [It's time for adventure! vol 5](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_5) | 3:53 |
| `dungeon_2.ogg` | 4〜6階（洞窟） | Cave of time | [Poupi's incredible adventures!](https://freemusicarchive.org/music/Komiku/Poupis_incredible_adventures_/) | 2:46 |
| `dungeon_3.ogg` | 7〜9階（深淵） | Remember this shadow | [It's time for adventure! vol 2](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_2) | 3:33 |
| `boss.ogg` | 10階のボス部屋 | The True Last Boss | [It's time for adventure! vol 5](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_5) | 7:24 |
| `game_over.ogg` | ゲームオーバー画面 | Sad walk with sad melodica | [It's time for adventure! vol 2](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_2) | 3:11 |
| `clear.ogg` | クリア画面 | Victory | [It's time for adventure! vol 2](https://freemusicarchive.org/music/Komiku/Its_time_for_adventure__vol_2) | 3:55 |

加工したこと：
- 元の MP3（320kbps、合計約80MB）を OGG Vorbis（約100kbps、合計約20MB）に変換。ブラウザ版の読み込みを軽くするため
- `dungeon_2.ogg` だけ元の音量が小さかったので、ほかの曲に合わせて約2倍に上げた
- どの曲も Godot の取り込み設定でループ再生をオンにしてある（`.import` の `loop=true`）

## 効果音（`sfx/`）

作者：**Juhani Junkala（SubspaceAudio）**
素材集：[The Essential Retro Video Game Sound Effects Collection [512 sounds]](https://opengameart.org/content/512-sound-effects-8-bit-style)（OpenGameArt、CC0）
ドット絵に合う 8bit 風の音でそろえています。WAV のまま（短い効果音は WAV のほうが Godot で遅れなく鳴る）。

| ファイル | 使う場面 | 元のファイル名 |
| --- | --- | --- |
| `attack_swing.wav` | プレイヤーの攻撃 | sfx_wpn_sword1 |
| `attack_miss.wav` | 攻撃が外れた | sfx_wpn_dagger |
| `hit_enemy.wav` | 敵にダメージ | sfx_damage_hit3 |
| `hit_player.wav` | プレイヤーがダメージを受けた | sfx_sounds_damage1 |
| `enemy_attack.wav` | 敵の攻撃 | sfx_wpn_punch1 |
| `enemy_die.wav` | 敵を倒した | sfx_exp_shortest_soft1 |
| `player_die.wav` | プレイヤーが倒れた | sfx_sounds_negative1 |
| `level_up.wav` | レベルアップ | sfx_sounds_powerup1 |
| `heal.wav` | 回復薬を飲んだ | sfx_sounds_powerup4 |
| `item_pickup.wav` | アイテムを拾った | sfx_coin_double1 |
| `equip.wav` | 武器・盾を装備 | sfx_sounds_interaction5 |
| `scroll_fire.wav` | 炎の巻物 | sfx_exp_short_soft1 |
| `scroll_warp.wav` | ワープの巻物 | sfx_movement_portal2 |
| `scroll_map.wav` | 地図の巻物 | sfx_sound_bling |
| `magic_bolt.wav` | 魔法使いの遠距離攻撃 | sfx_wpn_laser1 |
| `stairs_down.wav` | 階段を降りる | sfx_movement_portal1 |
| `trap.wav` | 罠を踏んだ | sfx_exp_shortest_hard1 |
| `footstep.wav` | 足音（うるさければ使わない） | sfx_movement_footsteps1a |
| `menu_move.wav` | メニューのカーソル移動 | sfx_menu_move1 |
| `menu_select.wav` | 決定 | sfx_menu_select1 |
| `menu_cancel.wav` | キャンセル・メニューを閉じる | sfx_sounds_pause1_out |
| `error.wav` | できない操作（持ち物がいっぱい など） | sfx_sounds_error1 |

## 入手経路のメモ

作業環境から OpenGameArt や Free Music Archive へ直接ダウンロードできなかったため、同じファイルを収録した GitHub 上の公開ミラーから取得しました。ライセンスは元の配布ページで確認しています。

- 効果音：[Mcamento8/open-game-sfx-index](https://github.com/Mcamento8/open-game-sfx-index)（Kenney と OpenGameArt の CC0 素材の索引）
- BGM：[SoundSafari/CC0-1.0-Music](https://github.com/SoundSafari/CC0-1.0-Music)（Free Music Archive などの CC0 曲の収集）

## ゲームのクレジット画面に載せる場合の例

```
Music: Komiku (CC0) — freemusicarchive.org/music/Komiku
Sound effects: Juhani Junkala / SubspaceAudio (CC0) — opengameart.org
```
