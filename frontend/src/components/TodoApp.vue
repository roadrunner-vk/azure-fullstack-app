<template>
  <div class="container">
    <h1>Todo App</h1>

    <form class="todo-form" @submit.prevent="addTodo">
      <input
        v-model="newTodo.title"
        placeholder="What needs to be done?"
        required
      />
      <input v-model="newTodo.description" placeholder="Description (optional)" />
      <input v-model="newTodo.due_date" type="date" />
      <button type="submit">Add</button>
    </form>

    <div class="filters">
      <button
        :class="{ active: filter === 'all' }"
        @click="filter = 'all'"
      >All</button>
      <button
        :class="{ active: filter === 'active' }"
        @click="filter = 'active'"
      >Active</button>
      <button
        :class="{ active: filter === 'done' }"
        @click="filter = 'done'"
      >Done</button>
    </div>

    <p v-if="loading" class="status">Loading...</p>
    <p v-else-if="error" class="status error">{{ error }}</p>

    <ul class="todo-list">
      <li
        v-for="todo in filteredTodos"
        :key="todo.id"
        :class="{ completed: todo.completed }"
      >
        <label class="todo-item">
          <input
            type="checkbox"
            :checked="todo.completed"
            @change="toggleTodo(todo)"
          />
          <div class="todo-content">
            <span class="title">{{ todo.title }}</span>
            <span v-if="todo.description" class="desc">{{ todo.description }}</span>
            <span v-if="todo.due_date" class="due">
              Due: {{ formatDate(todo.due_date) }}
            </span>
          </div>
        </label>
        <button class="delete-btn" @click="deleteTodo(todo.id)">&times;</button>
      </li>
    </ul>

    <p v-if="!loading && filteredTodos.length === 0" class="status">
      No todos to show.
    </p>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";

const todos = ref([]);
const loading = ref(true);
const error = ref(null);
const filter = ref("all");

const newTodo = ref({ title: "", description: "", due_date: "" });

const filteredTodos = computed(() => {
  if (filter.value === "active") return todos.value.filter((t) => !t.completed);
  if (filter.value === "done") return todos.value.filter((t) => t.completed);
  return todos.value;
});

function formatDate(iso) {
  return new Date(iso).toLocaleDateString();
}

async function fetchTodos() {
  loading.value = true;
  error.value = null;
  try {
    const res = await fetch("/api/todos/");
    if (!res.ok) throw new Error("Failed to fetch todos");
    todos.value = await res.json();
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

async function addTodo() {
  const body = { title: newTodo.value.title };
  if (newTodo.value.description) body.description = newTodo.value.description;
  if (newTodo.value.due_date) body.due_date = new Date(newTodo.value.due_date).toISOString();

  try {
    const res = await fetch("/api/todos/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error("Failed to create todo");
    const created = await res.json();
    todos.value.unshift(created);
    newTodo.value = { title: "", description: "", due_date: "" };
  } catch (e) {
    error.value = e.message;
  }
}

async function toggleTodo(todo) {
  try {
    const res = await fetch(`/api/todos/${todo.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ completed: !todo.completed }),
    });
    if (!res.ok) throw new Error("Failed to update todo");
    todo.completed = !todo.completed;
  } catch (e) {
    error.value = e.message;
  }
}

async function deleteTodo(id) {
  try {
    const res = await fetch(`/api/todos/${id}`, { method: "DELETE" });
    if (!res.ok) throw new Error("Failed to delete todo");
    todos.value = todos.value.filter((t) => t.id !== id);
  } catch (e) {
    error.value = e.message;
  }
}

onMounted(fetchTodos);
</script>
