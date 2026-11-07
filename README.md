# Torrent Guard

Фильтр открытого BitTorrent-трафика для Linux-серверов и VPN-нод, в том числе
Remnawave/Xray. Работает локально, без токена, внешнего API, телеметрии и
автоматической загрузки обновлений.

## Установка

Понадобятся Bash, `flock`, `iptables`, `ip6tables` и поддержка модуля `xt_string`
в ядре. На Ubuntu/Debian команды `iptables` и `ip6tables` входят в пакет
`iptables`. Для установки с автозапуском требуется systemd.

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

Скрипт добавляет свою цепочку `TORRENT_GUARD` к `OUTPUT` и `FORWARD` для IPv4
и IPv6. Она проверяет начало каждого пакета и отбрасывает совпадения с
TCP-рукопожатием BitTorrent, запросом подключения к UDP-трекеру и двумя типами
UDP-запросов DHT. Для трафика, созданного на самом сервере, проверяется исходящее
направление. Пересылаемый хостом трафик проверяется в обоих направлениях.
Остальной трафик продолжает проходить через текущие правила firewall.

Это фильтр по сигнатурам отдельных пакетов. Он может пропустить зашифрованный
BitTorrent, сигнатуры, разбитые по нескольким пакетам, и трафик, который выходит
с сервера внутри другого шифрованного туннеля. Открытый HTTP-трекер, HTTPS-трекер
и остальные варианты протокола не входят в набор сигнатур.

Форматы пакетов описаны в [BEP 3](https://www.bittorrent.org/beps/bep_0003.html),
[BEP 5](https://www.bittorrent.org/beps/bep_0005.html) и
[BEP 15](https://www.bittorrent.org/beps/bep_0015.html).
