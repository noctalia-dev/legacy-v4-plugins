# ТЗ: Noctalia plugin `clamshell`

## 1. Контекст и цель

Реализовать плагин для Noctalia Shell (Quickshell/QML), который автоматически
управляет clamshell-режимом ноутбука: при подключённом внешнем мониторе крышка
ноутбука перестаёт триггерить suspend (внутренний экран niri гасит сам), при
отключённом — лид-свич работает штатно.

Дополнительно — кнопка для принудительного отключения авто-поведения и
возврата к нему.

**Целевая платформа:** CachyOS (Arch-based), niri ≥ 0.1.9, Noctalia Shell
≥ 3.6.0, systemd, Quickshell (через noctalia-qs).

**Где живёт плагин:** `~/.config/noctalia/plugins/clamshell/`.

## 2. Принцип работы (high-level)

- Мониторим состояние выводов через `niri msg --json event-stream` (event-driven,
  без polling).
- Когда детектится хотя бы один внешний монитор и плагин не выключен пользователем
  — поднимаем долгоживущий процесс
  `systemd-inhibit --what=handle-lid-switch ... sleep infinity`. Пока он жив,
  logind игнорирует лид-свич; niri продолжает гасить внутренний экран по
  событию крышки.
- Когда внешних мониторов нет, или пользователь нажал «Disable» — процесс
  убивается, поведение возвращается к системному дефолту.
- Никаких изменений в `/etc/systemd/logind.conf` плагин **не делает**.

## 3. Функциональные требования

### 3.1. Состояния плагина

Плагин оперирует тремя независимыми источниками истины:

| Имя             | Тип    | Источник              | Описание                                        |
|-----------------|--------|-----------------------|-------------------------------------------------|
| `enabled`       | bool   | `pluginSettings`      | Включён ли вообще плагин (UI-toggle)            |
| `externalPresent` | bool | niri event-stream     | Есть ли хоть один внешний монитор в системе     |
| `inhibitorActive` | bool | derived (read-only)  | Запущен ли сейчас systemd-inhibit               |

Производное состояние:

```
inhibitorActive = enabled && externalPresent
```

Любое изменение `enabled` или `externalPresent` триггерит пересчёт и
старт/стоп процесса.

### 3.2. UI-кнопка (Control Center widget)

- Один тогл-баттон в Control Center.
- Визуальные состояния:
  - **Active** (`enabled && externalPresent`): подсвечен акцентным цветом,
    подпись «On — external display detected».
  - **Standby** (`enabled && !externalPresent`): обычный, подпись «Auto —
    no external display».
  - **Disabled** (`!enabled`): затемнён/outlined, подпись «Off».
- Клик переключает `enabled`. `externalPresent` остаётся как есть.

### 3.3. Bar widget (опциональный)

- Компактная иконка в баре. По умолчанию **показывается только когда
  `inhibitorActive == true`** (т.е. сейчас реально активен инхибитор).
- Пользователь может в Settings выбрать «всегда показывать»
  (`alwaysShowBarWidget`). При `alwaysShow=true` иконка отражает все три
  состояния (3 разных цвета/иконки).
- Клик на иконке = тогл `enabled`.
- Hover-tooltip: показывает текущее состояние и список детектированных
  выводов («eDP-1, DP-3 (external)»).

### 3.4. Settings UI

Минимальная панель настроек, рендерится в стандартный Noctalia Settings:

- `enabled` (bool, default `true`) — включён ли плагин.
- `alwaysShowBarWidget` (bool, default `false`).
- `notify` (bool, default `true`) — слать ли desktop-нотификации при
  изменении `inhibitorActive`.
- `internalConnectorRegex` (string, default `"^(eDP|LVDS|DSI)"`) — паттерн
  имён внутренних коннекторов; всё, что не матчится, считается внешним.
- `inhibitorWho` (string, default `"noctalia-clamshell"`) — значение
  `--who=` для systemd-inhibit (полезно для диагностики).
- Read-only блок: текущее состояние, список выводов с пометкой
  internal/external, PID активного inhibitor (если есть).

### 3.5. IPC

Плагин регистрирует IPC target `plugin:clamshell` со следующими функциями:

| Функция     | Аргументы | Возврат         | Эффект                                              |
|-------------|-----------|-----------------|-----------------------------------------------------|
| `enable`    | —         | `"ok"`          | `enabled = true`                                    |
| `disable`   | —         | `"ok"`          | `enabled = false`                                   |
| `toggle`    | —         | `"on"`/`"off"`  | Инвертирует `enabled`, возвращает новое значение    |
| `status`    | —         | JSON-строка     | См. ниже                                            |
| `refresh`   | —         | `"ok"`          | Принудительно перечитывает niri outputs             |

`status` возвращает JSON:

```json
{
  "enabled": true,
  "externalPresent": true,
  "inhibitorActive": true,
  "outputs": [
    {"name": "eDP-1", "internal": true,  "active": false},
    {"name": "DP-3",  "internal": false, "active": true}
  ]
}
```

Это нужно для биндов в niri (`spawn-sh "qs -c noctalia-shell ipc call
plugin:clamshell toggle"`) и интеграции со скриптами.

## 4. Авто-детект внешнего монитора

### 4.1. Источник событий

Использовать `niri msg --json event-stream` через `Quickshell.Io.Process`,
читать stdout построчно (каждое событие — JSON на отдельной строке).

niri event-stream спроектирован так, что присылает **полное текущее
состояние upfront**, а потом атомарные апдейты. То есть отдельный начальный
запрос `niri msg --json outputs` не нужен — первый пакет событий из стрима
уже содержит исходное состояние.

### 4.2. Релевантные события

Нас интересуют события об изменении конфигурации выводов. На момент
написания ТЗ это (точные имена варианта проверить в `niri-ipc` enum
`Event`, могут отличаться по версии):

- `OverviewOpenedOrClosed` — игнор.
- Любые `*Output*` / `*Outputs*` события — триггер пересчёта.
- Если конкретного output-события нет, fallback — на любое изменение
  считать `outputs` переменной и перечитывать список командой
  `niri msg --json outputs`.

**Реализация должна быть устойчива к появлению новых неизвестных
вариантов событий** (документация niri явно говорит об этом). Парсер
неизвестные ключи игнорирует.

### 4.3. Алгоритм детекции

```
on event:
    if event relates to outputs:
        outputs = niri msg --json outputs
        externals = [o for o in outputs
                     if not regex_match(internalConnectorRegex, o.name)
                     and o is connected]
        externalPresent = len(externals) > 0
```

«connected» = вывод физически присутствует. В niri JSON-схеме это
проверяется по наличию режимов (`modes` непусто) или статусу — уточнить
по факту в реализации; **отключённый пользователем (`niri msg output X
off`) внутренний дисплей всё равно считается присутствующим**, важна
именно физическая connectivity.

### 4.4. Восстановление при падении event-stream

Если процесс event-stream умер (niri рестартанул, и т.п.):

1. Логируем warning.
2. Ждём 2 секунды.
3. Перезапускаем процесс.
4. Повторно — exponential backoff до 30 секунд.

В период даунтайма event-stream `externalPresent` сохраняет последнее
известное значение. **Inhibitor не убиваем** только из-за падения
стрима — это бы привело к нежелательному suspend при простой ошибке
коммуникации.

## 5. Inhibitor: жизненный цикл процесса

### 5.1. Команда

```
systemd-inhibit \
    --what=handle-lid-switch \
    --who=<inhibitorWho> \
    --why=<i18n: "Clamshell mode — external display in use"> \
    --mode=block \
    sleep infinity
```

### 5.2. Запуск

`Process.running = inhibitorActive` — связать декларативно. QML сам
запустит/убьёт процесс при изменении свойства.

### 5.3. Корректное завершение

- При `inhibitorActive` → `false`: послать SIGTERM. `sleep infinity`
  завершается мгновенно, systemd-inhibit отпускает блокировку.
- При выгрузке плагина (Noctalia disable / shutdown): обязательно
  убить процесс. Quickshell `Process` должен делать это автоматически,
  но **верифицировать** в реализации — в Component.onDestruction.
- Если systemd-inhibit отсутствует в PATH — лог error, нотификация
  пользователю, плагин ведёт себя как `enabled=false` без возможности
  включения, в Settings UI показывается ошибка.

### 5.4. Уведомления

При каждом переходе `inhibitorActive` (при `notify=true`):

- `false → true`: notify-send «Clamshell ON — lid switch inhibited».
- `true → false`: notify-send «Clamshell OFF — normal lid behavior».

Иконка — `display`/`laptop` в зависимости от состояния. App ID —
`noctalia-clamshell`, чтобы пользователь мог отдельно настроить правила
DnD.

## 6. Структура файлов

```
clamshell/
├── manifest.json
├── preview.png
├── README.md
├── Main.qml                  # фоновая логика, event-stream, Process
├── ControlCenterWidget.qml   # тогл-баттон
├── BarWidget.qml             # индикатор
├── Settings.qml              # UI настроек
└── i18n/
    ├── en.json
    └── ru.json
```

## 7. Контракт `manifest.json`

```json
{
  "id": "clamshell",
  "name": "Clamshell Mode",
  "description": "Auto clamshell on external display, with manual override",
  "version": "0.1.0",
  "author": "<автор>",
  "license": "MIT",
  "minNoctaliaVersion": "3.6.0",
  "components": {
    "main": "Main.qml",
    "controlCenterWidget": "ControlCenterWidget.qml",
    "barWidget": "BarWidget.qml",
    "settings": "Settings.qml"
  },
  "defaultSettings": {
    "enabled": true,
    "alwaysShowBarWidget": false,
    "notify": true,
    "internalConnectorRegex": "^(eDP|LVDS|DSI)",
    "inhibitorWho": "noctalia-clamshell"
  },
  "ipc": {
    "target": "plugin:clamshell",
    "functions": ["enable", "disable", "toggle", "status", "refresh"]
  }
}
```

## 8. Архитектура `Main.qml` (skeleton-контракт)

Модуль `Main.qml` обязан экспортировать через `pluginApi.mainInstance`:

- свойства: `enabled` (rw), `externalPresent` (ro), `inhibitorActive` (ro),
  `outputs` (ro, list).
- сигналы: `stateChanged()` (любое изменение трёх state-bool).
- методы: `toggle()`, `enable()`, `disable()`, `refresh()`, `status()`.

Виджеты получают эти данные через `pluginApi.mainInstance.*`. Виджеты
**не должны** дублировать логику парсинга niri JSON или запускать свои
процессы.

## 9. Acceptance criteria

Плагин считается готовым, когда выполнены все пункты:

### 9.1. Авто-сценарий

1. Ноут без внешнего экрана, `enabled=true` → `inhibitorActive=false`,
   `systemd-inhibit --list | grep noctalia-clamshell` пусто.
2. Подключаем HDMI/DP → в течение **<1 секунды** `inhibitorActive=true`,
   `systemd-inhibit --list` показывает запись с `--who=noctalia-clamshell`.
3. Отключаем кабель → в течение **<1 секунды** inhibitor снят.
4. Закрытие крышки в состоянии (2): laptop **не** уходит в suspend,
   `eDP-1` гаснет.
5. Закрытие крышки в состоянии (1): laptop уходит в suspend как обычно.

### 9.2. Override-сценарий

6. В состоянии (2) кликнули кнопку Control Center → `enabled=false`,
   inhibitor моментально снят.
7. В этом же состоянии закрытие крышки → suspend (несмотря на
   подключённый внешний).
8. Повторный клик → `enabled=true`, при подключённом внешнем inhibitor
   восстанавливается.

### 9.3. IPC

9. `qs -c noctalia-shell ipc call plugin:clamshell toggle` инвертирует
   `enabled`, возвращает новое значение.
10. `qs -c noctalia-shell ipc call plugin:clamshell status` возвращает
    валидный JSON по схеме из 3.5.
11. Привязка хоткея в niri (`Mod+Shift+L`) на toggle работает идентично
    клику в UI.

### 9.4. Устойчивость

12. Перезапуск Noctalia: `enabled` восстанавливается из настроек,
    inhibitor поднимается заново если `externalPresent`.
13. `pkill niri` (имитация падения compositor): после рестарта niri
    плагин восстанавливает event-stream без вмешательства пользователя.
14. Удаление systemd-inhibit бинарника: плагин не падает, выдаёт
    видимую ошибку в UI.
15. Подключение/отключение мониторов 10 раз подряд: нет утечек
    процессов (`pgrep -f noctalia-clamshell` показывает не более одного).

### 9.5. Качество

16. Никаких лишних опросов (`niri msg outputs` вызывается только
    реактивно из event-stream, не по таймеру).
17. Inhibitor процесс корректно закрывается при выгрузке плагина
    (проверка: `qs ipc plugin:clamshell disable` + `pgrep -f
    "noctalia-clamshell"` пусто).
18. Логирование через `qs.Commons.Logger`, без `console.log` в
    проде.

## 10. Граничные случаи и решения

| Случай | Решение |
|--------|---------|
| Лид закрыт ДО старта плагина, внешний есть | niri уже погасил eDP, `externalPresent=true`, поднимаем inhibitor — корректно |
| Лид закрыт, внешний отключают | inhibitor снимается, **но крышка УЖЕ закрыта** → следующий лид-эвент случится только при открытии. logind в этом момент уже не в clamshell-режиме. Считаем это user error, документируем в README |
| Внешний — это второй встроенный экран (DSI на конвертах) | regex `internalConnectorRegex` настраивается пользователем |
| Несколько внешних подряд: HDMI вытыкают, DP всё ещё есть | `externalPresent` остаётся `true`, inhibitor не дёргается |
| Suspend/resume цикл | event-stream может выжить или умереть, см. 4.4. После resume — niri в любом случае шлёт фуллстейт через стрим |
| Hibernate | После hibernate ситуация идентична resume |
| Multi-seat / multi-user | Out of scope. Inhibitor работает в рамках сессии текущего пользователя |

## 11. Что НЕ входит в скоуп

- Lock-screen при закрытии крышки (это задача niri `switch-events` или
  swayidle, не плагина).
- Управление DPMS / brightness внешнего экрана.
- Ручной выбор какие именно мониторы триггерят clamshell (всё или
  ничего).
- Hot-plug audio (sink switching) — это другой плагин.
- Откат `HandleLidSwitchDocked=ignore` если он был выставлен ранее —
  только упомянуть в README, что для корректной работы плагина в
  `logind.conf` должно быть значение по умолчанию (`suspend`).

## 12. Тест-план

Помимо acceptance criteria выше, перед мержем прогнать:

1. **Unit-уровень (вручную, без фреймворка):** запустить плагин, дёргать
   IPC `enable`/`disable`/`toggle`/`status` → сверить с
   `systemd-inhibit --list`.
2. **Имитация event-stream:** подменить `niri` фиктивным скриптом,
   эмулирующим события подключения/отключения — проверить реакцию.
3. **Запись лога:** прогнать сценарии 9.1–9.4, в `journalctl --user -u
   noctalia*` не должно быть ошибок (warning от backoff допустимы).
4. **Память:** оставить плагин на 24 часа с периодическим
   plug/unplug — RSS Quickshell не должен расти линейно.

## 13. Полезные ссылки для реализации

- niri IPC: <https://yalter.github.io/niri/IPC.html>
- niri-ipc Rust crate (полные определения событий и outputs):
  <https://docs.rs/niri-ipc/>
- Noctalia plugin docs:
  <https://docs.noctalia.dev/development/plugins/overview/>
- Hello-world пример (всё включено):
  <https://github.com/noctalia-dev/noctalia-plugins> → `hello-world/`
- systemd-inhibit man: `man systemd-inhibit`, особенно секция о
  `--what=handle-lid-switch` и `--mode=block`.

## 14. Вопросы открытые на усмотрение реализатора

- Конкретный набор событий event-stream, на которые подписываться
  (зависит от версии niri-ipc, проверить в crate).
- Какую именно иконку использовать для bar widget — на выбор из
  доступных в Noctalia icon set.
- Структура read-only Settings блока (таблица vs список).
- Использовать ли direct UNIX socket к `$NIRI_SOCKET` вместо запуска
  `niri msg` процесса (производительнее, но усложняет код). Допустимо
  оба варианта; для начала — через `Process` с `niri msg`.

---

**Definition of Done:** все 18 acceptance criteria выполнены,
README с примером настройки niri-биндинга и одной картинкой preview.png
лежит в репозитории, плагин ставится через стандартный механизм
Noctalia Plugin Registry (или из локальной папки).
