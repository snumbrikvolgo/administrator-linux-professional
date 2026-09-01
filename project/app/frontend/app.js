async function refresh() {
  const [who, articles] = await Promise.all([
    fetch("/api/whoami").then(r => r.json()),
    fetch("/api/articles").then(r => r.json())
  ]);
  document.querySelector("#backend").textContent = who.backend;
  const list = document.querySelector("#articles");
  list.innerHTML = "";
  articles.forEach(article => {
    const li = document.createElement("li");
    li.textContent = `${article.title}: ${article.body}`;
    const btn = document.createElement("button");
    btn.textContent = "Delete";
    btn.className = "delete";
    btn.onclick = async () => {
      await fetch(`/api/articles/${article.id}`, { method: "DELETE" });
      refresh();
    };
    li.appendChild(btn);
    list.appendChild(li);
  });
}

document.querySelector("#create").onclick = async () => {
  await fetch("/api/articles", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title: document.querySelector("#title").value,
      body: document.querySelector("#body").value
    })
  });
  document.querySelector("#title").value = "";
  document.querySelector("#body").value = "";
  refresh();
};

refresh();
