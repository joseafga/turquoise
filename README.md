# Turquoise

![Turquoise Profile Picture](./img/profile_small.png?raw=true "Turquoise Profile Picture")

Telegram bot for YouTube notifications and fun.

**Blue** (Telegram) + **Green** (Midori) + **Crystal** (Programming Language) = **Turquoise**

## Installation

Rename `.env.example` to `.env` and configure according to your needs.

Load environment variables

```bash
source .env
export DATABASE_URL
```

Run Micrate to setup database

```bash
bin/micrate create
bin/micrate up
```

Run or build bot and worker

```bash
crystal run src/turquoise.cr -- -m 'Ready!' &
crystal run src/worker.cr
```

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it (<https://github.com/joseafga/turquoise/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [José Almeida](https://github.com/joseafga) - creator and maintainer
