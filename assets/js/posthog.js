const POSTHOG_METHODS = [
  "init",
  "capture",
  "register",
  "register_once",
  "register_for_session",
  "unregister",
  "unregister_for_session",
  "getFeatureFlag",
  "getFeatureFlagPayload",
  "isFeatureEnabled",
  "reloadFeatureFlags",
  "identify",
  "group",
  "reset",
  "get_distinct_id",
  "get_session_id",
  "alias",
  "set_config",
  "startSessionRecording",
  "stopSessionRecording",
  "captureException",
  "opt_in_capturing",
  "opt_out_capturing",
  "has_opted_in_capturing",
  "has_opted_out_capturing",
  "debug"
];

function metaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content || "";
}

function addStubMethod(target, method) {
  const parts = method.split(".");
  let receiver = target;
  let name = method;

  if (parts.length === 2) {
    receiver = target[parts[0]];
    name = parts[1];
  }

  receiver[name] = function(...args) {
    target.push([name, ...args]);
  };
}

function scriptSource(apiHost) {
  return apiHost.replace(".i.posthog.com", "-assets.i.posthog.com") + "/static/array.js";
}

function installPostHogStub() {
  const existing = window.posthog || [];
  if (existing.__SV) return existing;

  window.posthog = existing;
  existing._i = [];

  existing.init = function(projectKey, config, name = "posthog") {
    const script = document.createElement("script");
    script.type = "text/javascript";
    script.crossOrigin = "anonymous";
    script.async = true;
    script.src = scriptSource(config.api_host);

    const firstScript = document.getElementsByTagName("script")[0];
    if (firstScript?.parentNode) {
      firstScript.parentNode.insertBefore(script, firstScript);
    } else {
      document.head.appendChild(script);
    }

    const target = name === "posthog" ? existing : (existing[name] = []);
    target.people = target.people || [];
    target.toString = function(stub) {
      return "posthog" + (name === "posthog" ? "" : `.${name}`) + (stub ? "" : " (stub)");
    };
    target.people.toString = function() {
      return target.toString(true) + ".people (stub)";
    };

    POSTHOG_METHODS.forEach((method) => addStubMethod(target, method));
    existing._i.push([projectKey, config, name]);
  };

  existing.__SV = 1;
  return existing;
}

function captureLiveViewPageviews(client) {
  let lastUrl = window.location.href;

  window.addEventListener("phx:page-loading-stop", () => {
    window.setTimeout(() => {
      const nextUrl = window.location.href;
      if (nextUrl === lastUrl) return;

      lastUrl = nextUrl;
      client.capture("$pageview");
    }, 0);
  });
}

export function initPostHog() {
  const apiKey = metaContent("posthog-api-key");
  const apiHost = metaContent("posthog-api-host");

  if (!apiKey || !apiHost) return;

  const app = metaContent("posthog-app") || "zonely";
  const env = metaContent("posthog-env") || "prod";
  const posthog = installPostHogStub();

  posthog.init(apiKey, {
    api_host: apiHost,
    defaults: "2026-01-30",
    autocapture: false,
    capture_pageview: true,
    capture_pageleave: true,
    disable_session_recording: true,
    loaded: (client) => {
      client.register({app, env, platform: "web"});
      captureLiveViewPageviews(client);
    }
  });
}
