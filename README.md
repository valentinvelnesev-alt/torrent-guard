# Torrent Guard

Фильтр открытого BitTorrent-трафика для Linux-серверов и VPN-нод, в том числе
Remnawave/Xray. Работает локально, без токена, внешнего API, телеметрии и
автоматической загрузки обновлений.

## Установка

Понадобятся Bash, `flock`, `iptables`, `ip6tables` и поддержка модулей `xt_string` и `xt_connbytes`
в ядре. На Ubuntu/Debian команды `iptables` и `ip6tables` входят в пакет
`iptables`. Для установки с автозапуском требуется systemd.

Для установки с автозапуском одной командой понадобится `curl`.

```bash
curl -fsSL https://github.com/valentinvelnesev-alt/torrent-guard/raw/main/install.sh | sudo sh
```

Чтобы сначала применить правила временно, скачай репозиторий.

```bash
git clone https://github.com/valentinvelnesev-alt/torrent-guard.git
cd torrent-guard
sudo bash guard.sh apply
sudo bash guard.sh status
```

`apply` применяет правила до перезагрузки. Проверь доступ по SSH и работу VPN,
затем включи автозапуск.

```bash
sudo bash guard.sh install
```

## Управление

```bash
# Посмотреть правила и счётчики отброшенных пакетов
sudo torrent-guard status

# Восстановить правила после перезагрузки конфигурации firewall
sudo torrent-guard apply

# Снять правила до следующего запуска сервиса или перезагрузки
sudo torrent-guard remove

# Удалить правила и автозапуск
sudo torrent-guard uninstall
```

До установки команды `status` и `remove` доступны через `sudo bash guard.sh`.

## Что фильтруется

Скрипт добавляет свою цепочку `TORRENT_GUARD` к `INPUT`, `OUTPUT` и `FORWARD`
для IPv4 и IPv6. Он ищет сигнатуры TCP-рукопожатия BitTorrent, открытых
HTTP-запросов к трекеру, подключения к UDP-трекеру, запросов DHT и локального
обнаружения пиров. Для соединений со счётчиками conntrack поиск ограничен
первыми 8 КиБ трафика в обоих направлениях вместе. Остальной трафик проходит
через текущие правила firewall.

Фильтр ищет сигнатуры в отдельных пакетах. Он может пропустить зашифрованный
BitTorrent, HTTPS-трекеры, сигнатуры, разбитые по нескольким пакетам, и трафик,
который выходит с сервера внутри другого шифрованного туннеля.

Форматы пакетов описаны в [BEP 3](https://www.bittorrent.org/beps/bep_0003.html),
[BEP 5](https://www.bittorrent.org/beps/bep_0005.html),
[BEP 14](https://www.bittorrent.org/beps/bep_0014.html) и
[BEP 15](https://www.bittorrent.org/beps/bep_0015.html).
