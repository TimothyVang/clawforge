#!/usr/bin/env node
/**
 * team-ops Discord MCP — bot REST API (stdio JSON-RPC MCP).
 * Env: DISCORD_BOT_TOKEN (required for live calls), DISCORD_GUILD_ID (optional default)
 * Fallback guidance when token missing: CDP http://127.0.0.1:9230
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const API = "https://discord.com/api/v10";
const TOKEN = process.env.DISCORD_BOT_TOKEN || "";
const DEFAULT_GUILD = process.env.DISCORD_GUILD_ID || "";
const CDP_HINT =
  process.env.HACKATHON_CDP_URL || "http://127.0.0.1:9230";

function missingTokenError() {
  return {
    content: [
      {
        type: "text",
        text: [
          "DISCORD_BOT_TOKEN is not set.",
          "Set it in team-ops/.env after following discord/bot-setup.md.",
          `Browser fallback: open Discord on CDP ${CDP_HINT} (hackathon session).`,
          "From hackathon root: ./scripts/open-sites.sh https://discord.com/app",
        ].join("\n"),
      },
    ],
    isError: true,
  };
}

async function discord(method, path, body) {
  if (!TOKEN) {
    const err = new Error("NO_TOKEN");
    err.code = "NO_TOKEN";
    throw err;
  }
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bot ${TOKEN}`,
      "Content-Type": "application/json",
      "User-Agent": "team-ops-discord-mcp (https://github.com/local/team-ops)",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    const msg = typeof data === "object" ? JSON.stringify(data) : text;
    throw new Error(`Discord API ${res.status}: ${msg}`);
  }
  return data;
}

function ok(payload) {
  return {
    content: [
      {
        type: "text",
        text:
          typeof payload === "string"
            ? payload
            : JSON.stringify(payload, null, 2),
      },
    ],
  };
}

const server = new Server(
  { name: "team-ops-discord", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "discord_status",
      description:
        "Check whether Discord bot token is configured and bot identity",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
    },
    {
      name: "discord_list_channels",
      description: "List text channels in a guild (server)",
      inputSchema: {
        type: "object",
        properties: {
          guild_id: {
            type: "string",
            description: "Guild snowflake (default DISCORD_GUILD_ID)",
          },
        },
        additionalProperties: false,
      },
    },
    {
      name: "discord_send_message",
      description: "Send a message to a channel by snowflake ID",
      inputSchema: {
        type: "object",
        properties: {
          channel_id: { type: "string", description: "Channel snowflake" },
          content: {
            type: "string",
            description: "Message body (max 2000 chars)",
          },
        },
        required: ["channel_id", "content"],
        additionalProperties: false,
      },
    },
    {
      name: "discord_read_messages",
      description: "Read recent messages from a channel",
      inputSchema: {
        type: "object",
        properties: {
          channel_id: { type: "string" },
          limit: {
            type: "number",
            description: "1-50 (default 20)",
          },
        },
        required: ["channel_id"],
        additionalProperties: false,
      },
    },
    {
      name: "discord_create_thread",
      description: "Create a public thread on a message or channel",
      inputSchema: {
        type: "object",
        properties: {
          channel_id: { type: "string" },
          name: { type: "string" },
          message_id: {
            type: "string",
            description: "Optional message to attach thread to",
          },
          auto_archive_minutes: {
            type: "number",
            description: "60|1440|4320|10080",
          },
        },
        required: ["channel_id", "name"],
        additionalProperties: false,
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name;
  const args = request.params.arguments || {};

  try {
    if (name === "discord_status") {
      if (!TOKEN) return missingTokenError();
      const me = await discord("GET", "/users/@me");
      return ok({
        ok: true,
        bot: { id: me.id, username: me.username },
        guild_id_default: DEFAULT_GUILD || null,
        cdp_fallback: CDP_HINT,
      });
    }

    if (name === "discord_list_channels") {
      if (!TOKEN) return missingTokenError();
      const guild = args.guild_id || DEFAULT_GUILD;
      if (!guild) {
        return {
          content: [
            {
              type: "text",
              text: "guild_id required (or set DISCORD_GUILD_ID)",
            },
          ],
          isError: true,
        };
      }
      const channels = await discord("GET", `/guilds/${guild}/channels`);
      const simplified = (channels || [])
        .filter((c) => c.type === 0 || c.type === 5 || c.type === 15)
        .map((c) => ({
          id: c.id,
          name: c.name,
          type: c.type,
          parent_id: c.parent_id,
        }));
      return ok(simplified);
    }

    if (name === "discord_send_message") {
      if (!TOKEN) return missingTokenError();
      const content = String(args.content || "").slice(0, 2000);
      const msg = await discord(
        "POST",
        `/channels/${args.channel_id}/messages`,
        { content },
      );
      return ok({
        id: msg.id,
        channel_id: msg.channel_id,
        content: msg.content,
      });
    }

    if (name === "discord_read_messages") {
      if (!TOKEN) return missingTokenError();
      const limit = Math.min(50, Math.max(1, Number(args.limit) || 20));
      const messages = await discord(
        "GET",
        `/channels/${args.channel_id}/messages?limit=${limit}`,
      );
      const simplified = (messages || []).map((m) => ({
        id: m.id,
        author: m.author?.username,
        content: m.content,
        timestamp: m.timestamp,
      }));
      return ok(simplified);
    }

    if (name === "discord_create_thread") {
      if (!TOKEN) return missingTokenError();
      const body = {
        name: String(args.name).slice(0, 100),
        auto_archive_duration: args.auto_archive_minutes || 1440,
        type: 11,
      };
      let path;
      if (args.message_id) {
        path = `/channels/${args.channel_id}/messages/${args.message_id}/threads`;
      } else {
        path = `/channels/${args.channel_id}/threads`;
        body.type = 11;
      }
      const thread = await discord("POST", path, body);
      return ok({ id: thread.id, name: thread.name });
    }

    return {
      content: [{ type: "text", text: `Unknown tool: ${name}` }],
      isError: true,
    };
  } catch (e) {
    if (e && e.code === "NO_TOKEN") return missingTokenError();
    return {
      content: [{ type: "text", text: String(e.message || e) }],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
