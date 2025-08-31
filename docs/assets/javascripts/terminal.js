document.addEventListener("DOMContentLoaded", () => {
  const terminal = document.getElementById("terminal");

  const session = [
    { cmd: "cd /knowledge/base", output: "" },
    { cmd: "ls -la", output: "drwxr-xr-x  5 user  staff  160 Aug 31 18:00 .\ndrwxr-xr-x 10 user  staff  320 Aug 31 17:50 ..\n-rw-r--r--  1 user  staff  0 Aug 31 18:00 readme.md" },
    { cmd: "cat readme.md", output: "Welcome to the knowledge base!\nHere you can find all docs and notes." },
  ];

  let lineIndex = 0;

  function typeLine(lineObj) {
    // создаём новую строку с курсором
    const p = document.createElement("p");
    const prompt = document.createElement("span");
    prompt.classList.add("command-prompt");
    prompt.textContent = "user@skynet:~$ ";
    const currentLine = document.createElement("span");
    const cursor = document.createElement("span");
    cursor.classList.add("cursor");
    p.appendChild(prompt);
    p.appendChild(currentLine);
    p.appendChild(cursor);
    terminal.appendChild(p);

    let charIndex = 0;

    function typeChar() {
      if(charIndex < lineObj.cmd.length) {
        currentLine.textContent += lineObj.cmd[charIndex];
        charIndex++;
        setTimeout(typeChar, 50 + Math.random()*100); // имитация случайной скорости печати
        terminal.scrollTop = terminal.scrollHeight;
      } else {
        // после команды выводим результат
        if(lineObj.output) {
          const outputP = document.createElement("p");
          outputP.textContent = lineObj.output;
          terminal.appendChild(outputP);
        }

        // удаляем текущий курсор
        cursor.remove();

        // запускаем следующую команду с небольшой задержкой
        lineIndex++;
        if(lineIndex < session.length) {
          setTimeout(() => typeLine(session[lineIndex]), 500 + Math.random()*300);
        }
      }
    }

    typeChar();
  }

  typeLine(session[lineIndex]);
});
