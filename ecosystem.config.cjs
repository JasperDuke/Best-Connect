/**
 * PM2 process manager config for HR Connect.
 *
 * This repo is a single Node/Express app (API + static UI in public/).
 * One process is all you need — there is no separate frontend server.
 *
 * Usage:
 *   npm run pm2:start
 *   npm run pm2:logs
 *   npm run pm2:restart
 *   npm run pm2:stop
 */
module.exports = {
  apps: [
    {
      name: 'hr-connect',
      script: 'server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      watch: false,
      // App logs (PM2 also writes its own logs under ~/.pm2/logs/)
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      merge_logs: true,
      time: true,
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        // Public URL port — serves both UI and API
        PORT: 3000
      }
    }
  ]
};
