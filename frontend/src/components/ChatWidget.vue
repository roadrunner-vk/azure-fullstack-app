<template>
  <div class="chat-widget">
    <button class="chat-toggle" @click="isOpen = !isOpen">
      <span v-if="!isOpen">💬</span>
      <span v-else>✕</span>
    </button>

    <div v-if="isOpen" class="chat-panel">
      <div class="chat-header">
        <span>AI Assistant</span>
      </div>

      <div class="chat-messages" ref="messagesEl">
        <div
          v-for="(msg, i) in messages"
          :key="i"
          :class="['chat-msg', msg.role]"
        >
          <div class="msg-content">{{ msg.content }}</div>
        </div>
        <div v-if="loading" class="chat-msg assistant">
          <div class="msg-content typing">Thinking...</div>
        </div>
      </div>

      <form class="chat-input" @submit.prevent="sendMessage">
        <input
          v-model="input"
          placeholder="Ask anything..."
          :disabled="loading"
        />
        <button type="submit" :disabled="loading || !input.trim()">Send</button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick } from "vue";

const isOpen = ref(false);
const input = ref("");
const messages = ref([]);
const loading = ref(false);
const messagesEl = ref(null);

async function sendMessage() {
  const text = input.value.trim();
  if (!text) return;

  messages.value.push({ role: "user", content: text });
  input.value = "";
  loading.value = true;
  scrollToBottom();

  try {
    const res = await fetch("/api/chat/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ messages: messages.value }),
    });
    if (!res.ok) throw new Error("Failed to get response");
    const data = await res.json();
    messages.value.push({ role: "assistant", content: data.reply });
  } catch (e) {
    messages.value.push({ role: "assistant", content: "Sorry, something went wrong." });
  } finally {
    loading.value = false;
    scrollToBottom();
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesEl.value) {
      messagesEl.value.scrollTop = messagesEl.value.scrollHeight;
    }
  });
}
</script>
