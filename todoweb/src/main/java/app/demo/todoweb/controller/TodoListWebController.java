package app.demo.todoweb.controller;

import java.util.ArrayList;
import java.util.Date;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

import app.demo.todoweb.dto.Todo;
import app.demo.todoweb.dto.TodoPage;
import app.demo.todoweb.service.TodoService;
import app.demo.todoweb.utils.AppLogger;
import app.demo.todoweb.utils.Utils;

@Controller
public class TodoListWebController {

	public static final AppLogger LOGGER = new AppLogger(TodoListWebController.class);

	private TodoService todoService;

	@Autowired
	public TodoListWebController(TodoService service) {
		this.todoService = service;
	}

	@GetMapping("/")
	public String getTodos(Model model) {
		LOGGER.debug("TODO GET called with action '/'");

		initPageHeader(model, false);
		initPageTodoList(model);

		return "todo";
	}

	@GetMapping("/add-new")
	public String addNewGet(Model model) {
		LOGGER.debug("TODO GET called with action '/add-new'");

		initPageHeader(model, true);
		initPageTodoList(model);

		return "todo";
	}

	@PostMapping(value = "/add-new")
	public String addNew(@ModelAttribute TodoPage page, Model model) {
		LOGGER.debug("TODO POST called with action '/add-new'");

		initPageHeader(model, true);
		processTodoList(model, page);

		return "todo";
	}

	@RequestMapping(value = "/close-msg-box", method = RequestMethod.POST)
	public String closeMsgBox(@ModelAttribute TodoPage page, Model model) {
		LOGGER.debug("TODO POST called with action '/cancel'");

		initPageHeader(model, false);
		processTodoList(model, page);

		return "todo";
	}

	@RequestMapping(value = "/cancel", method = RequestMethod.POST)
	public String cancel(@ModelAttribute TodoPage page, Model model) {
		LOGGER.debug("TODO POST called with action '/cancel'");

		initPageHeader(model, false);
		processTodoList(model, page);

		return "todo";
	}

	@RequestMapping(value = "/update-refresh", method = RequestMethod.POST)
	public String updateRefresh(@ModelAttribute TodoPage page, Model model) {
		LOGGER.debug("TODO POST called with action '/update-refresh'");

		initPageHeader(model, page != null && page.getTodoText() != null);
		if (page.getTodoText() != null) {
			setFormTodoText(model, page.getTodoText());
		}
		processTodoList(model, page);

		return "todo";
	}

	@RequestMapping(value = "/submit", method = RequestMethod.POST)
	public String submit(@ModelAttribute TodoPage page, Model model) {

		LOGGER.debug(String.format("TODO POST called with action '/submit' :\n%s", page.toString()));

		initPageHeader(model, true);

		if (page.getTodoText() == null || page.getTodoText().trim() == "") {
			LOGGER.error("Unable to save a new TODO; TODO is empty.");
			setCreateTodoMode(model, true);
			setFormMessage(model, "error", "New Todo cannot be empty. Please fill in the text.");
		} else {
			try {
				var todo = todoService.createTodo(page.getTodoText());

				setFormMessage(model, "saved",
						String.format("Task '%s' has been saved.", Utils.shortenString(page.getTodoText())));

				setCreateTodoMode(model, false);
				LOGGER.debug(String.format("TODO POST with action '/submit' finished successfully (%s)", todo.getId()));

			} catch (Exception ex) {
				LOGGER.error(String.format("Failed to save a new TODO (%s)", ex.getMessage()), ex);
				setCreateTodoMode(model, true);
				setFormMessage(model, "error", "Error while saving the new task. Please try again later.");
			}
		}

		processTodoList(model, page);

		return "todo";
	}

	private void initPageHeader(Model model, boolean createMode) {

		model.addAttribute("createMode", createMode);
		model.addAttribute("formStatus", "");
		model.addAttribute("formMessage", "");
		model.addAttribute("todoListStatus", "");
		model.addAttribute("todoListMessage", "");
		model.addAttribute("page", new TodoPage());
	}

	private void setFormMessage(Model model, String formStatus, String formMessage) {
		model.addAttribute("formStatus", formStatus);
		model.addAttribute("formMessage", formMessage);
	}

	private void setTodoListMessage(Model model, String todoListStatus, String todoListMessage) {
		model.addAttribute("todoListStatus", todoListStatus);
		model.addAttribute("todoListMessage", todoListMessage);
	}

	private void setCreateTodoMode(Model model, boolean createMode) {
		model.addAttribute("createMode", createMode);
	}

	private void setFormTodoText(Model model, String todoText) {
		TodoPage page;

		if (model.containsAttribute("page")) {
			page = (TodoPage) model.getAttribute("page");
		} else {
			page = new TodoPage();
			model.addAttribute("page", page);
		}
		page.setTodoText(todoText);
	}

	private boolean hasTodoListError(Model model) {
		return model != null && model.getAttribute("todoListStatus") == "error";
	}

	private void initPageTodoList(Model model) {
		TodoPage page;

		if (model.containsAttribute("page")) {
			page = (TodoPage) model.getAttribute("page");
		} else {
			page = new TodoPage();
			model.addAttribute("page", page);
		}

		try {
			var todos = todoService.getTodos();
			if (todos == null)
				todos = new ArrayList<Todo>();
			page.setTodoList(todos);
			model.addAttribute("page", page);
		} catch (Exception ex) {
			LOGGER.error(String.format("Failed to retrieve the list of TODOs (%s)", ex.getMessage()), ex);
			model.addAttribute("page", page);
			if (!this.hasTodoListError(model)) {
				// Do not overwrite a possibly moder important error
				model.addAttribute("todoListStatus", "error");
				model.addAttribute("todoListMessage", "Failed to fetch Todos. Please try again later.");
			}
		}
	}

	private void processTodoList(Model model, TodoPage page) {
		LOGGER.debug("Starting to process Todo List changes");
		try {
			var todoList = page.getTodoList();
			if (todoList != null) {
				for (Todo todo : todoList) {
					if (todo.getCompleted() != todo.getCompletedOrig()) {
						LOGGER.debug(String.format("Changes in completed status of TODO '%s' detected", todo.getId()));
						var retrievedTodo = todoService.getTodo(todo.getId());

						if (todo.getCompleted() && retrievedTodo.getCompletedDateTime() == null) {
							retrievedTodo.setCompletedDateTime(new Date());
							var updatedTodo = todoService.updateTodo(retrievedTodo);
							LOGGER.debug(String.format("Processing TODO '%s': completed set to 'true'",
									updatedTodo.getId()));
						} else if (!todo.getCompleted() && retrievedTodo.getCompletedDateTime() != null) {
							retrievedTodo.setCompletedDateTime(null);
							var updatedTodo = todoService.updateTodo(retrievedTodo);
							LOGGER.debug(String.format("Processing TODO '%s': completed set to 'false'",
									updatedTodo.getId()));
						} else if (todo.getCompletedDateTime() != retrievedTodo.getCompletedDateTime()) {
							LOGGER.debug(String.format("Processing TODO '%s': no update needed (1)", todo.getId()));
						}
					} else {
						LOGGER.debug(String.format("Processing TODO '%s': no update needed (2)", todo.getId()));
					}
				}
			}
			initPageTodoList(model);
		} catch (Exception ex) {
			LOGGER.error(String.format("An error has occured while updating TODO (%s)", ex.getMessage()), ex);
			setTodoListMessage(model,
					"error",
					"An error has occured while updating Todos. Please try again later.");
		}
	}
}