#!/usr/bin/env node

const https = require('https');
const url = require('url');

// 環境変数から設定を取得
const webhookUrl = process.env.SLACK_WEBHOOK_URL;
const channel = process.env.SLACK_CHANNEL;
const username = process.env.SLACK_USERNAME || 'Sandbox Notifier';
const iconEmoji = process.env.SLACK_ICON_EMOJI || ':robot_face:';

// コマンドライン引数からメッセージを取得
const message = process.argv.slice(2).join(' ');

// エラーチェック
if (!webhookUrl) {
  console.error('❌ Error: SLACK_WEBHOOK_URL environment variable is not set');
  console.error('Please set it in your .env file (agent-sandbox repo root)');
  process.exit(1);
}

if (!message) {
  console.error('❌ Error: No message provided');
  console.error('Usage: slack-notify <message>');
  process.exit(1);
}

// Slack通知送信関数
async function sendSlackMessage(text) {
  const parsedUrl = url.parse(webhookUrl);
  
  // 最小限のペイロードから始める
  const payload = {
    text: text
  };
  
  // オプションフィールドを追加（Webhookの設定によっては無視される場合がある）
  if (username) {
    payload.username = username;
  }
  
  if (iconEmoji) {
    payload.icon_emoji = iconEmoji;
  }
  
  // チャンネルは多くのWebhookで変更不可のため、環境変数が明示的に設定されている場合のみ追加
  if (channel) {
    console.log('⚠️  Warning: Channel override may not work with some Webhook configurations');
    payload.channel = channel;
  }
  
  const data = JSON.stringify(payload);
  
  const options = {
    hostname: parsedUrl.hostname,
    path: parsedUrl.path,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data, 'utf8')
    }
  };
  
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('✅ Message sent to Slack successfully');
          resolve();
        } else {
          console.error(`❌ Failed to send message: ${res.statusCode}`);
          console.error('Response:', responseData);
          
          // デバッグ情報を表示
          console.error('\nDebug information:');
          console.error('Payload sent:', JSON.stringify(payload, null, 2));
          console.error('Webhook URL:', webhookUrl.replace(/\/[^\/]+$/, '/***')); // URLの最後の部分を隠す
          
          reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
        }
      });
    });
    
    req.on('error', (error) => {
      console.error('❌ Error sending message:', error.message);
      reject(error);
    });
    
    req.write(data);
    req.end();
  });
}

// メイン処理
(async () => {
  try {
    await sendSlackMessage(message);
  } catch (error) {
    process.exit(1);
  }
})();
