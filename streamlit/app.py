"""Minimal chat UI for the LiteLLM gateway.

Talks to LiteLLM, never to RunPod directly — so the model alias, the key, the
budget, and the rate limit all apply exactly as they would for any other client.
That is the point of putting it behind the gateway rather than pointing it at
the pod.

Configuration is entirely environment:
  LITELLM_BASE_URL   e.g. http://34.1.2.3:4000
  LITELLM_API_KEY    master key, or a virtual key with a model allowlist
  DEFAULT_MODEL      alias to preselect
"""

import os

import streamlit as st
from openai import OpenAI

BASE_URL = os.environ.get("LITELLM_BASE_URL", "http://litellm-gateway:4000")
API_KEY = os.environ.get("LITELLM_API_KEY", "")
DEFAULT_MODEL = os.environ.get("DEFAULT_MODEL", "terraform-code-fast")

st.set_page_config(page_title="Terraforge Chat", page_icon="🛠️", layout="centered")


@st.cache_resource
def client() -> OpenAI:
    # v1 is appended here rather than being part of the env var, so the same
    # base URL works for the /health check below.
    return OpenAI(base_url=f"{BASE_URL}/v1", api_key=API_KEY or "missing")


@st.cache_data(ttl=60)
def available_models() -> list[str]:
    """Ask the gateway what it serves. Falls back to the default on error so a
    momentarily unreachable gateway does not leave an empty, unusable form."""
    try:
        return sorted(m.id for m in client().models.list().data)
    except Exception:
        return [DEFAULT_MODEL]


with st.sidebar:
    st.subheader("Gateway")
    st.caption(BASE_URL)

    models = available_models()
    model = st.selectbox(
        "Model",
        models,
        index=models.index(DEFAULT_MODEL) if DEFAULT_MODEL in models else 0,
        help="Aliases come from the gateway, not from this app.",
    )

    # Qwen3 is a hybrid reasoning model: left on, it writes a <think> block
    # before answering, and a small max_tokens gets spent entirely on that —
    # the response comes back truncated with finish_reason "length" and no
    # actual answer. Off by default here because most chat turns are short.
    thinking = st.toggle(
        "Reasoning (<think>)",
        value=False,
        help="Qwen3 reasons before answering. Useful for code, wasteful for "
        "one-liners. Needs a larger token budget when on.",
    )
    max_tokens = st.slider("Max tokens", 128, 4096, 1024 if thinking else 512, 128)
    temperature = st.slider("Temperature", 0.0, 1.5, 0.7, 0.1)

    st.divider()
    if st.button("Clear conversation"):
        st.session_state.messages = []
        st.rerun()

st.title("🛠️ Terraforge Chat")

if not API_KEY:
    st.error("LITELLM_API_KEY is not set; every request will be rejected.")

if "messages" not in st.session_state:
    st.session_state.messages = []

for m in st.session_state.messages:
    with st.chat_message(m["role"]):
        st.markdown(m["content"])

if prompt := st.chat_input("Ask about Terraform..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        placeholder = st.empty()
        answer = ""
        try:
            kwargs = {
                "model": model,
                "messages": st.session_state.messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
                "stream": True,
            }
            if not thinking:
                # vLLM extension, not standard OpenAI. LiteLLM's drop_params
                # may strip it; if reasoning shows up anyway, that is why.
                kwargs["extra_body"] = {
                    "chat_template_kwargs": {"enable_thinking": False}
                }

            for chunk in client().chat.completions.create(**kwargs):
                delta = chunk.choices[0].delta.content or ""
                answer += delta
                placeholder.markdown(answer + "▌")
            placeholder.markdown(answer)
        except Exception as exc:
            # Show the gateway's own error rather than a stack trace: an
            # exhausted budget or a model the key is not allowed to use are
            # both normal outcomes here, and both say so plainly.
            placeholder.error(f"{type(exc).__name__}: {exc}")
            answer = ""

    if answer:
        st.session_state.messages.append({"role": "assistant", "content": answer})
