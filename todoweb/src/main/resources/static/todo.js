"use-strict";

const TIMEOUT_INFO=10000;
const TIMEOUT_ERROR=20000;
const TIMEOUT_PROGRESS=100000;

function saveTodo(repeats) {
  let newTodoInputTextElement = document.getElementById("new-todo-input-text");
  let newTodoText = newTodoInputTextElement.value;
  if (newTodoText == undefined || newTodoText.trim() == "") {
    displayTaskCreateFormMessage("error", "New Todo text should not be empty.");
    return;
  }

  displayTaskCreateFormMessage("saving", "Saving the new Todo...");

  fetch(`/api/todos/`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ todoText: newTodoText }),
  })
    .then((response) => {
      if (response.ok) {
        response
          .text()
          .then((text) => {
            console.log(`Received '${response.status}', task has been saved, contining with parsing.`);
            try {
              let jsonTodo = JSON.parse(text);
              if (jsonTodo == null || jsonTodo.todoText === undefined || jsonTodo.todoText == null || jsonTodo.todoText === "") {
                throw "Empty task received from the server as a confirmation";
              }

              addTodoToList(jsonTodo);

              let todoMsgText = jsonTodo.todoText;
              if (todoMsgText.length > 5) {
                todoMsgText = `${todoMsgText.substring(todoMsgText, 5)}...`;
              }

              displayTodoListMessage("saved", `Task '${todoMsgText}' has beed saved.`, 0);
              hideAddTodoForm();
              showCommandBar();
            } catch (ex) {
              //Unable to parse, but the task has been saved
              console.log(`An exception '${ex}' ocurred, but the task was most likely saved.`);
              hideAddTodoForm();
              showCommandBar();
              displayTodoListMessage("error", "Task has beed saved, but the server response is malformated. Try to refresh the page.", 0);
            }
          })
          .catch((reason) => {
            //Server returned another error, reduce number of requests and wait longer
            if (repeats > 1) {
              console.log(`An exception '${reason}' ocurred, will try again.`);
              setTimeout(saveTodo, 100 + parseInt(Math.random() * 500), repeats - 1);
            } else {
              console.log(`An exception '${reason}' ocurred, giving up.`);
              displayTaskCreateFormMessage("error", "An error has occured while retrieving the task status. Please try again later.");
            }
          });
      } else {
        if (repeats > 1) {
          console.log(`Received '${response.status}', will try again.`);
          setTimeout(saveTodo, 100 + parseInt(Math.random() * 500), repeats - 1);
        } else {
          console.log(`Received '${response.status}' and tried too many times already, giving up.`);
          displayTaskCreateFormMessage("error", "An error has occured while saving the task. Please try again later.");
        }
      }
    })
    .catch((reason) => {
      console.log(`Exception '${reason}', occured, giving up.`);
      displayTaskCreateFormMessage("error", "An error has occured while saving the task. Please try again later.");
    });
}

function closeTodoListMessageBoxText(elementId) {
  let messageText = document.getElementById(elementId);
  if (messageText === null) {
    return;
  }
  parentElement = messageText.parentElement;

  if (parentElement.children.length > 2) {
    // min size = 1 + close-button
    messageText.parentElement.removeChild(messageText);
  } else {
    let progressBar = document.getElementById(`${parentElement.id}-progress-bar`);
    if (progressBar === null) {
      let parentId = parentElement.parentElement.id;
      progressBar = document.getElementById(`${parentId}-progress-bar`);
    }

    if (progressBar !== null) {
      progressBar.parentElement.removeChild(progressBar);
    }

    messageText.parentElement.parentElement.removeChild(messageText.parentElement);
  }
}

function closeMessageBox(elementId) {
  let messageBox = document.getElementById(elementId);
  if (messageBox === null) {
    return;
  }

  let progressBar = document.getElementById(`${elementId}-progress-bar`);
  if (progressBar !== null) {
    progressBar.parentElement.removeChild(progressBar);
  }

  messageBox.parentElement.removeChild(messageBox);
}

function onMessageBoxCloseClicked(e) {
  e.preventDefault();
  let currentElement = e.target;
  while (currentElement.type !== "div" && !currentElement.classList.contains("message-box")) {
    currentElement = currentElement.parentElement;
  }
  closeMessageBox(currentElement.id);
}

function createProgressBar(elementId) {
  let progressBar = document.createElement("progress");
  progressBar.setAttribute("id", elementId);
  progressBar.classList.add("progress-bar");
  return progressBar;
}

function setStatusClass(element, status) {
  if (element.classList.contains(status)) {
    return; //there is only up to one status class assigned at any time
  }

  const statusList = ["saving", "saved", "none", "info", "warning", "error"];

  for (let i = 0; i < statusList.length; i++) {
    const currentStatus = statusList[i];
    if (element.classList.contains(currentStatus)) {
      element.classList.remove(currentStatus);
    }
  }

  element.classList.add(status);
}
function createMessageBoxText(textElementId, status, text) {
  let messageText = document.createElement("div");
  messageText.setAttribute("id", textElementId);
  messageText.classList.add("message-text");
  messageText.classList.add(status);
  messageText.appendChild(document.createTextNode(text));
  return messageText;
}

function createMessageBox(boxElementId, textElementId, status, text) {
  //Create message box
  let messageBox = document.createElement("div");
  messageBox.setAttribute("id", boxElementId);
  messageBox.classList.add("message-box");

  //Add message text
  let messageText = createMessageBoxText(textElementId, status, text);
  messageBox.appendChild(messageText);

  //Add close button
  let closeButton = document.createElement("button");
  closeButton.setAttribute("type", "submit");
  closeButton.setAttribute("action", "/close-msg-box");
  closeButton.setAttribute("id", `${boxElementId}-close-button`);
  closeButton.classList.add("close-icon");
  let closeImg = document.createElement("img");
  closeImg.setAttribute("src", "cancel.svg");
  closeImg.setAttribute("title", "Clear");
  closeImg.setAttribute("alt", "Clear message");
  closeImg.classList.add("close-img");
  closeButton.appendChild(closeImg);
  closeButton.addEventListener("click", onMessageBoxCloseClicked);
  messageBox.appendChild(closeButton);

  return messageBox;
}

function getMessageTimeout(status) {
  let messageTimeout = null;
  
  switch(status) {
    case "error":
      messageTimeout = TIMEOUT_ERROR;
      break;
    case "info":
      messageTimeout = TIMEOUT_INFO;
      break;
    case "saved":
      messageTimeout = TIMEOUT_INFO;
      break;
    case "saving":
      messageTimeout = TIMEOUT_PROGRESS;
      break;
  }
  
  return messageTimeout;
}

let taskCreateFormMessageHidingTimer = 0;

function displayTaskCreateFormMessage(status, msgText) {
  if (taskCreateFormMessageHidingTimer) {
    clearTimeout(taskCreateFormMessageHidingTimer);
    taskCreateFormMessageHidingTimer = 0;
  }

  let todoCreateForm = document.getElementById("todo-create-form");
  let todoSaveButton = document.getElementById("todo-save-button");

  let messageBox = document.getElementById("todo-create-form-message-box");
  if (messageBox == undefined) {
    let messageBox = createMessageBox("todo-create-form-message-box", "todo-create-form-message-box-text", status, msgText);
    todoCreateForm.insertBefore(messageBox, todoSaveButton);
  } else {
    const textDiv = document.getElementById("todo-create-form-message-box-text");
    textDiv.innerText = msgText;

    setStatusClass(textDiv, status);
  }

  let progressBar = document.getElementById("todo-create-form-message-box-progress-bar");
  if (status === "saving") {
    if (progressBar === null) {
      todoSaveButton.parentElement.insertBefore(createProgressBar("todo-create-form-message-box-progress-bar"), todoSaveButton);
    }
  } else if (progressBar !== null) {
    progressBar.parentElement.removeChild(progressBar);
  }

  let hideAfterMs = getMessageTimeout(status);
  if (hideAfterMs !== null) {
    taskCreateFormMessageHidingTimer = setTimeout(closeMessageBox, hideAfterMs, "todo-create-form-message-box");
  }
}

let todoListMessageHidingTimer = [];

function displayTodoListMessage(status, msgText, msgIdx) {
  if (todoListMessageHidingTimer.includes(msgIdx) && todoListMessageHidingTimer[msgIdx]) {
    clearTimeout(todoListMessageHidingTimer[msgIdx]);
    todoListMessageHidingTimer[msgIdx] = 0;
  }

  let todoSection = document.getElementById("todos");
  let todoList = document.getElementById("todo-list");

  let messageBox = document.getElementById("todo-list-message-box");
  if (messageBox === null) {
    let messageBox = createMessageBox("todo-list-message-box", `todo-list-message-box-text-${msgIdx}`, status, msgText);
    todoSection.insertBefore(messageBox, todoList);
  } else {
    let textDiv = document.getElementById(`todo-list-message-box-text-${msgIdx}`);
    if (textDiv === null) {
      textDiv = createMessageBoxText(`todo-list-message-box-text-${msgIdx}`, status, msgText);
      if (messageBox.children[0].length > 0) {
        messageBox.insertBefore(textDiv, messageBox.children[0]);
      } else {
        messageBox.appendChild(textDiv);
      }
    } else {
      textDiv.innerText = msgText;
    }

    setStatusClass(textDiv, status);
  }

  let progressBar = document.getElementById("todo-list-message-box-progress-bar");
  if (status === "saving") {
    if (progressBar === null) {
      todoSection.insertBefore(createProgressBar("todo-list-message-box-progress-bar"), todoList);
    }
  } else if (progressBar !== null) {
    progressBar.parentElement.removeChild(progressBar);
  }
  
  let hideAfterMs = getMessageTimeout(status);
  if (hideAfterMs !== null) {
    todoListMessageHidingTimer[msgIdx] = setTimeout(closeTodoListMessageBoxText, hideAfterMs, `todo-list-message-box-text-${msgIdx}`);
  }
}

function addTodoToList(todo) {
  console.log(`Adding a todo '${todo.id}' to the UL list of HTML LI elements.`);

  let newTodoElement = document.createElement("li");
  newTodoElement.classList.add("todo-item");
  newTodoElement.classList.add("created");
  newTodoElement.setAttribute("key", todo.id);

  let newTodoCompleteCheckboxElement = document.createElement("input");
  newTodoCompleteCheckboxElement.setAttribute("type", "checkbox");
  newTodoCompleteCheckboxElement.setAttribute("id", `completed-${todo.id}`);
  newTodoCompleteCheckboxElement.setAttribute("class", "complete-checkbox");

  newTodoElement.appendChild(newTodoCompleteCheckboxElement);

  let newTodoTextSpan = document.createElement("span");
  newTodoTextSpan.setAttribute("id", `todo-text-${todo.id}`);
  newTodoTextSpan.appendChild(document.createTextNode(todo.todoText));
  newTodoElement.appendChild(newTodoTextSpan);

  let newTodoStatusTextDivElement = document.createElement("div");
  newTodoStatusTextDivElement.setAttribute("id", `status-text-${todo.id}`);
  newTodoStatusTextDivElement.classList.add("todo-status");
  newTodoStatusTextDivElement.appendChild(document.createTextNode(todo.statusText));
  newTodoElement.appendChild(newTodoStatusTextDivElement);

  let origTodoCompleteCheckboxElement = document.createElement("input");
  origTodoCompleteCheckboxElement.setAttribute("hidden", "");
  origTodoCompleteCheckboxElement.setAttribute("id", `orig-completed-${todo.id}`);
  origTodoCompleteCheckboxElement.setAttribute("value", `${todo.completedOrig}`);
  newTodoElement.appendChild(origTodoCompleteCheckboxElement);

  let todoListElement = document.getElementById("todo-list");
  if (todoListElement.children.length > 0) {
    todoListElement.insertBefore(newTodoElement, todoListElement.children[0]);
  } else {
    todoListElement.appendChild(newTodoElemelement);
  }

  let allTodosFinishedElement = document.getElementById("todo-list-empty");
  if (allTodosFinishedElement != undefined) {
    console.log(`Removing the 'All todos finished' message.`);
    todoListElement.removeChild(allTodosFinishedElement);
  }
  console.log(`New Todo '${todo.id}' added successfully to the UL list of HTML LI elements.`);
}

function showAddTodoForm() {
  let localTodoForm = document.getElementById("todo-create");
  if (localTodoForm !== null) {
    return;
  }

  let addTodoSectionElememt = document.createElement("section");
  addTodoSectionElememt.setAttribute("id", "todo-create");

  let formElememt = document.createElement("div");
  formElememt.setAttribute("id", "todo-create-form");
  addTodoSectionElememt.appendChild(formElememt);

  let formControlDivElement = document.createElement("div");
  formControlDivElement.setAttribute("class", "form-control");
  formElememt.appendChild(formControlDivElement);

  let labelElememt = document.createElement("label");
  labelElememt.setAttribute("id", "todo-label");
  labelElememt.setAttribute("for", "new-todo-input-text");
  labelElememt.appendChild(document.createTextNode("New task"));

  let inputTextElememt = document.createElement("input");
  inputTextElememt.setAttribute("type", "text");
  inputTextElememt.setAttribute("id", "new-todo-input-text");

  formControlDivElement.appendChild(inputTextElememt);
  formControlDivElement.insertBefore(labelElememt, inputTextElememt);

  let submitButtonElememt = document.createElement("button");
  submitButtonElememt.setAttribute("type", "submit");
  submitButtonElememt.setAttribute("class", "button");
  submitButtonElememt.setAttribute("value", "create");
  submitButtonElememt.setAttribute("id", "todo-save-button");
  submitButtonElememt.appendChild(document.createTextNode("Save"));
  submitButtonElememt.addEventListener("click", onSaveConfirmButtonClick);
  formElememt.appendChild(submitButtonElememt);

  formElememt.appendChild(document.createTextNode(" "));

  let cancelButtonElememt = document.createElement("button");
  cancelButtonElememt.setAttribute("type", "submit");
  cancelButtonElememt.setAttribute("class", "button");
  cancelButtonElememt.setAttribute("value", "cancel");
  cancelButtonElememt.setAttribute("id", "todo-cancel-button");
  cancelButtonElememt.appendChild(document.createTextNode("Cancel"));
  cancelButtonElememt.addEventListener("click", onSaveCancelButtonClick);
  formElememt.appendChild(cancelButtonElememt);

  let todosSectionElement = document.getElementById("todos");
  todosSectionElement.parentElement.insertBefore(addTodoSectionElememt, todosSectionElement);
}

function hideAddTodoForm() {
  let addTodoSectionElememt = document.getElementById("todo-create");
  if (addTodoSectionElememt == undefined) {
    return;
  }
  addTodoSectionElememt.parentElement.removeChild(addTodoSectionElememt);
}

function showCommandBar() {
  let commandBar = document.getElementById("todos-command-bar");
  if (commandBar !== null) {
    commandBar.style.display = "unset";
  }
}

function hideCommandBar() {
  let commandBar = document.getElementById("todos-command-bar");
  if (commandBar != undefined) {
    commandBar.style.display = "none";
  }
}

function onTodosCreateButtonClick(e) {
  e.preventDefault();
  showAddTodoForm();
  hideCommandBar();
}

function onSaveConfirmButtonClick(e) {
  e.preventDefault();
  saveTodo(5);
}

function onSaveCancelButtonClick(e) {
  e.preventDefault();
  hideAddTodoForm();
  showCommandBar();
}

function refreshUpdate(repeats) {
  let todoList = document.getElementById("todo-list");
  if (todoList === null) {
    return;
  }

  let modifiedTodos = [];
  for (let i = 0; i < todoList.children.length; i++) {
    const key = todoList.children.item(i).attributes["key"].value;
    if (key === null) {
      continue;
    }
    const completedCheckbox = document.getElementById(`completed-${key}`);
    const completedCheckboxOrig = document.getElementById(`orig-completed-${key}`);
    if (completedCheckbox !== null && completedCheckboxOrig !== null) {
      if (completedCheckbox.checked !== (completedCheckboxOrig.value === "true")) {
        let updatedTodo = {
          id: key,
          completed: completedCheckbox.checked,
          completedOrig: completedCheckboxOrig.value === "true",
        };
        modifiedTodos.push(updatedTodo);
      }
    }
  }

  if (modifiedTodos.length < 1) {
    displayTodoListMessage("info", "No updated Todo(s) found, skipping the save...", 1);
    return;
  }

  displayTodoListMessage("saving", "Saving updated Todo(s)...", 1);

  fetch(`/api/todos/`, {
    method: "PATCH",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(modifiedTodos),
  })
    .then((response) => {
      if (response.ok) {
        response
          .text()
          .then((text) => {
            console.log(`Received '${response.status}', Todo(s) have been saved, continuing with parsing.`);
            try {
              let jsonTodoList = JSON.parse(text);
              if (jsonTodoList === null || jsonTodoList.length < 1) {
                throw "Empty Todo list received from the server as a confirmation";
              }
              for (let i = 0; i < jsonTodoList.length; i++) {
                let jsonTodo = jsonTodoList[i];
                if (jsonTodo.id !== null) {
                  let completedElement = document.getElementById(`completed-${jsonTodo.id}`);
                  let origCompletedElement = document.getElementById(`orig-completed-${jsonTodo.id}`);
                  let todoTextElement = document.getElementById(`todo-text-${jsonTodo.id}`);
                  let statusTextElement = document.getElementById(`status-text-${jsonTodo.id}`);
                  if (jsonTodo.completed !== null && completedElement !== null) {
                    completedElement.checked = jsonTodo.completed;
                  }
                  if (jsonTodo.origCompleted !== null && origCompletedElement !== null) {
                    origCompletedElement.value = `${jsonTodo.completedOrig}`;
                  }
                  if (jsonTodo.todoText !== null && todoTextElement !== null) {
                    todoTextElement.innerText = jsonTodo.todoText;
                  }
                  if (jsonTodo.statusText !== null && statusTextElement !== null) {
                    statusTextElement.innerText = jsonTodo.statusText;
                  }
                }
              }
              displayTodoListMessage("saved", ` ${jsonTodoList.length} Todo(s) have beed updated.`, 1);
            } catch (ex) {
              //Unable to parse, but the task has been saved
              console.log(`An exception '${ex}' ocurred, but Todo(s) were most likely saved.`);
              displayTodoListMessage("error", "Todo(s) have been updated, but the server response is malformated. Try to refresh the page.", 1);
            }
          })
          .catch((reason) => {
            //Server returned another error, reduce number of requests and wait longer
            if (repeats > 1) {
              console.log(`An exception '${reason}' ocurred will try again.`);
              setTimeout(refreshUpdate, 100 + parseInt(Math.random() * 500), repeats - 1);
            } else {
              console.log(`An exception '${reason}' ocurred, giving up.`);
              displayTodoListMessage("error", "An error has occured while retrieving the update status. Please try again later.", 1);
            }
          });
      } else {
        if (repeats > 1) {
          console.log(`Received '${response.status}', will try again.`);
          setTimeout(refreshUpdate, 100 + parseInt(Math.random() * 500), repeats - 1);
        } else {
          console.log(`Received '${response.status}' and tried too many times already, giving up.`);
          displayTodoListMessage("error", "An error has occured while updating Todo(s). Please try again later.", 1);
        }
      }
    })
    .catch((reason) => {
      if (repeats > 1) {
        console.log(`Exception '${reason}', will try again.`);
        setTimeout(refreshUpdate, 100 + parseInt(Math.random() * 500), repeats - 1);
      } else {
        console.log(`Exception '${reason}', occured, giving up.`);
        displayTodoListMessage("error", "An error has occured while updating Todo(s). Please try again later (2).", 1);
      }
    });
}

function onTodosRefreshUpdateButtonClick(e) {
  e.preventDefault();
  refreshUpdate(4);
}

function onDocumentLoad() {
  let addButton = document.getElementById("todos-create-button");
  if (addButton !== null) {
    addButton.addEventListener("click", onTodosCreateButtonClick);
  }
  let refreshUpdateButton = document.getElementById("todos-update-refresh-button");
  if (refreshUpdateButton != null) {
    refreshUpdateButton.addEventListener("click", onTodosRefreshUpdateButtonClick);
  }

  let cancelButton = document.getElementById("todo-cancel-button");
  if (cancelButton != undefined) {
    cancelButton.addEventListener("click", onSaveCancelButtonClick);
  }
  let saveConfirmButton = document.getElementById("todo-save-button");
  if (saveConfirmButton != undefined) {
    saveConfirmButton.addEventListener("click", onSaveConfirmButtonClick);
  }
}

window.onload = onDocumentLoad;
