# Zonely Ops

`../mini-infra` is the golden path for production operations. Keep this repo focused on app code and delegate deployment/service control through the local `Justfile`.

Daily commands:

```sh
just status
just health
just logs
just tail
```

Change commands:

```sh
just deploy
just migrate
just restart
just rollback
just install
```

Runtime env file on Mini:

```sh
~/.config/zonely/env.runtime
```

Expected production values include `DATABASE_URL=postgresql://zonely:...@127.0.0.1:5432/zonely_prod`, `SECRET_KEY_BASE`, `PHX_HOST=zonely.qingbo.us`, `PORT=4020`, and optionally `PRONUNCIATION_API_KEY` for production pronunciation API access.
