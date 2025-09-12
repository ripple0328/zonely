module.exports = {
  apps: [{
    name: 'zonely-prod',
    script: 'mix',
    args: 'prod.tunnel',
    cwd: '/Users/qingbo/Projects/Personal/zonely',
    interpreter: 'none',

    // Process management
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',

    // Environment
    env: {
      NODE_ENV: 'production',
      PATH: process.env.PATH,
      HOME: process.env.HOME,
      USER: process.env.USER
    },

    // Logging
    out_file: './logs/prod.log',
    error_file: './logs/prod.error.log',
    log_file: './logs/combined.log',
    time: true,

    // Restart policy
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
}
