![GitHub License](https://img.shields.io/github/license/Morningstar2808/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/Morningstar2808/OpenWrt-nikki?style=for-the-badge&logo=github)

**Языки:** [English](README.md) | [Русский](README.ru.md)

# Nikki

Прозрачный прокси с Mihomo на OpenWrt.

## Чем это отличается от исходного проекта

- Собственная система нумерации версий, начиная с 1.27.0 — на один минор впереди оригинального проекта
- Пакеты публикуются только как GitHub Releases; пока нет репозитория пакетов, поэтому обновление означает повторный запуск скрипта установки
- Сборки ограничены архитектурами `aarch64_cortex-a53`, `aarch64_generic`, `mipsel_24kc`, `x86_64` для OpenWrt 24.10 и 25.12

Теги с суффиксом (`v1.27.0-rc1`) публикуются как предварительные версии, теги без суффикса (`v1.27.0`) — как обычные релизы.

## Требования

- OpenWrt 24.10 или 25.12
- Ядро Linux >= 5.13
- firewall4

## Возможности

- Прозрачный прокси (Redirect/TPROXY/TUN, IPv4 и/или IPv6)
- Контроль доступа
- Объединение профилей
- Редактор профилей
- Запланированный перезапуск
- Пользовательские HTTP-заголовки для загрузки подписок (HWID и т. п.)

## Установка и обновление

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```

Скрипт определяет архитектуру маршрутизатора и ветку OpenWrt, загружает соответствующий пакет из последнего выпуска (включая предварительные версии) и устанавливает его. Повторный запуск скрипта — это способ обновления, и его можно повторять без опасений: затрагиваются только те пакеты, версия которых отличается от установленной, поэтому при запуске без изменений сервис остаётся без изменений, а не перезапускается.

Переводы LuCI по умолчанию не устанавливаются — интерфейс остаётся на английском языке. Скрипт выводит список переводов, содержащихся в сборке.

Опции (аргументы или соответствующие переменные окружения `NIKKI_*`):

```shell
# Переводы LuCI: коды через пробел или all
wget -O - .../install.sh | ash -s -- --lang ru
wget -O - .../install.sh | ash -s -- --lang "ru zh-cn"
# Конкретный релиз / другое зеркало
wget -O - .../install.sh | ash -s -- --tag v1.27.0-rc2 --repo owner/repo
# Переустановить, даже если версии совпадают
wget -O - .../install.sh | ash -s -- --force
# Справка
wget -O - .../install.sh | ash -s -- --help
```

Ядром всегда является `mihomo-meta`, собранный из тегированных выпусков MetaCubeX.

### Ручная установка

Если скрипт использовать невозможно:

```shell
# 1. Определите вашу архитектуру и ветку
. /etc/openwrt_release; echo "$DISTRIB_ARCH $DISTRIB_RELEASE"
# 2. Скачайте nikki_<arch>-<branch>.tar.gz со страницы «Релизы»
# 3. Распакуйте и установите
tar -x -z -f nikki_<arch>-<branch>.tar.gz
opkg install ./*.ipk                      # OpenWrt 24.10
apk add --allow-untrusted ./*.apk         # OpenWrt 25.12
```

## Удаление и сброс настроек

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash
```

## Как использовать

См. [Вики-страницу исходного проекта](https://github.com/nikkinikki-org/OpenWrt-nikki/wiki).

## Как это работает

1. Объединение и обновление профиля
2. Запуск mihomo
3. Установка запланированного перезапуска
4. Установка IP-правил/маршрутов
5. Генерация nftables и применение их

Примечание: указанные выше шаги могут меняться в зависимости от конфигурации.

## Компиляция

```shell
# Добавить репозиторий
echo "src-git nikki https://github.com/Morningstar2808/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# Обновить и установить репозитории
./scripts/feeds update -a
./scripts/feeds install -a
# Скомпилировать пакет
make package/luci-app-nikki/compile
```

Файлы пакета будут находиться в каталоге `bin/packages/your_architecture/nikki`.

## Зависимости

- ca-bundle
- curl
- yq
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- kmod-dummy
