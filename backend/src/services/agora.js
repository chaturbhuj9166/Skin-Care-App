// Agora RTC token generation service — STUBBED whenever real Agora
// credentials are not configured.
//
// Mirrors the shape of the real `agora-token` package (RtcTokenBuilder) so
// swapping in production credentials later is a one-line change inside
// generateRtcToken() — every call site (doctor.controller.js) stays the same.
const crypto = require('crypto');
const env = require('../config/env');

const isConfigured = Boolean(env.AGORA_APP_ID && env.AGORA_APP_CERTIFICATE);

const DEFAULT_EXPIRATION_SECONDS = 60 * 60; // 1 hour

/**
 * Generates an RTC token for a video-call channel.
 * @param {string} channelName - typically the VideoCall.roomId
 * @param {number|string} [uid] - numeric UID of the joining user (0 = let Agora assign one)
 * @returns {string} an Agora RTC token, or a clearly-labeled placeholder token
 */
function generateRtcToken(channelName, uid = 0) {
  if (!isConfigured) {
    const fake = `stub-agora-token-${crypto.randomBytes(12).toString('hex')}`;
    console.log(
      `[AGORA STUB] No AGORA_APP_ID/AGORA_APP_CERTIFICATE configured — generating placeholder token for channel "${channelName}"`
    );
    return fake;
  }

  // Real implementation once AGORA_APP_ID / AGORA_APP_CERTIFICATE are set:
  //
  //   const { RtcTokenBuilder, RtcRole } = require('agora-token');
  //   const expireAt = Math.floor(Date.now() / 1000) + DEFAULT_EXPIRATION_SECONDS;
  //   return RtcTokenBuilder.buildTokenWithUid(
  //     env.AGORA_APP_ID,
  //     env.AGORA_APP_CERTIFICATE,
  //     channelName,
  //     uid,
  //     RtcRole.PUBLISHER,
  //     expireAt
  //   );
  const { RtcTokenBuilder, RtcRole } = require('agora-token');
  const expireAt = Math.floor(Date.now() / 1000) + DEFAULT_EXPIRATION_SECONDS;
  return RtcTokenBuilder.buildTokenWithUid(
    env.AGORA_APP_ID,
    env.AGORA_APP_CERTIFICATE,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    expireAt
  );
}

module.exports = { generateRtcToken, isConfigured };
