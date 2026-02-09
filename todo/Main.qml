import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  property var pluginApi: null

  Component.onCompleted: {
    if (pluginApi) {
      if (!pluginApi.pluginSettings.pages) {
        pluginApi.pluginSettings.pages = [
          {
            id: 0,
            name: "General"
          }
        ];
        pluginApi.pluginSettings.current_page_id = 0;
      }

      if (!pluginApi.pluginSettings.todos) {
        pluginApi.pluginSettings.todos = [];
        pluginApi.pluginSettings.count = 0;
        pluginApi.pluginSettings.completedCount = 0;
      }

      if (pluginApi.pluginSettings.isExpanded === undefined) {
        pluginApi.pluginSettings.isExpanded = false;
      }

      // Ensure all existing todos have a pageId and priority
      var todos = pluginApi.pluginSettings.todos;
      for (var i = 0; i < todos.length; i++) {
        if (todos[i].pageId === undefined) {
          todos[i].pageId = 0;
        }
        if (todos[i].priority === undefined || typeof todos[i].priority !== 'string') {
          todos[i].priority = "medium";
        } else {
          var validPriorities = ["high", "medium", "low"];
          if (validPriorities.indexOf(todos[i].priority) === -1) {
            todos[i].priority = "medium";
          }
        }
        if (todos[i].details === undefined) {
          todos[i].details = "";
        }
      }

      // Initialize useCustomColors
      if (pluginApi.pluginSettings.useCustomColors === undefined) {
        pluginApi.pluginSettings.useCustomColors = false;
      }

      // Initialize priority colors
      if (!pluginApi.pluginSettings.priorityColors) {
        pluginApi.pluginSettings.priorityColors = {
          "high": Color.mError,
          "medium": Color.mPrimary,
          "low": Color.mOnSurfaceVariant
        };
      }

      pluginApi.saveSettings();
    }
  }

  IpcHandler {
    target: "plugin:todo"


    function togglePanel() {
      pluginApi.withCurrentScreen(screen => {
        pluginApi.togglePanel(screen);
      });
    }

    function addTodo(text: string, pageId: int, priority: string) {
      if (!pluginApi || !text) return;

      // Validate page ID
      if (!isValidPageId(pageId)) {
        Logger.e("Todo", "Invalid pageId: " + pageId);
        return;
      }

      // Validate and normalize priority
      var validatedPriority = validatePriority(priority);

      var todos = pluginApi.pluginSettings.todos || [];

      var newTodo = {
        id: Date.now(),
        text: text,
        completed: false,
        createdAt: new Date().toISOString(),
        pageId: pageId,
        priority: validatedPriority,
        details: ""
      };

      todos.push(newTodo);

      pluginApi.pluginSettings.todos = todos;
      pluginApi.pluginSettings.count = todos.length;
      pluginApi.saveSettings();

      ToastService.showNotice(pluginApi?.tr("main.added_new_todo") + text);
    }

    function addTodoDefault(text: string) {
      addTodo(text, 0, "medium");
    }

    function toggleTodo(id: string) {
      if (!pluginApi || parseInt(id) < 0) return;

      var todo = findTodoById(id);

      if (todo) {
        // Use the helper function to update the todo
        var success = updateTodo(id, {
          completed: !todo.completed
        });

        if (success) {
          pluginApi.pluginSettings.todos = pluginApi.pluginSettings.todos;

          // Recalculate completed count
          pluginApi.pluginSettings.completedCount = calculateCompletedCount();
          pluginApi.saveSettings();

          // Get the updated todo to determine its new status
          var updatedTodo = findTodoById(id);
          var action = updatedTodo.completed ? pluginApi?.tr("main.todo_completed") : pluginApi?.tr("main.todo_marked_incomplete");
          var message = pluginApi?.tr("main.todo_status_changed");
          ToastService.showNotice(message + action);
        }
      } else {
        var message = pluginApi?.tr("main.todo_not_found");
        var endMessage = pluginApi?.tr("main.not_found_suffix");
        ToastService.showError(message + id + endMessage);
      }
    }

    function clearCompleted() {
      if (!pluginApi) return;

      var todos = pluginApi.pluginSettings.todos || [];
      var activeTodos = todos.filter(todo => !todo.completed);

      pluginApi.pluginSettings.todos = activeTodos;
      pluginApi.pluginSettings.count = activeTodos.length;

      // Recalculate completed count using helper function
      pluginApi.pluginSettings.completedCount = calculateCompletedCount();
      pluginApi.saveSettings();

      var clearedCount = todos.length - activeTodos.length;
      var message = pluginApi?.tr("main.cleared_completed_todos");
      var suffix = pluginApi?.tr("main.completed_todos_suffix");
      ToastService.showNotice(message + clearedCount + suffix);
    }

    function removeTodo(id: string) {
      if (!pluginApi || parseInt(id) < 0) return;

      var todos = pluginApi.pluginSettings.todos || [];
      var indexToRemove = -1;

      for (var i = 0; i < todos.length; i++) {
        if (todos[i].id.toString() === id) {
          indexToRemove = i;
          Logger.i("Todo", "Found todo at index: " + i);
          break;
        }
      }

      if (indexToRemove !== -1) {
        todos.splice(indexToRemove, 1);

        pluginApi.pluginSettings.todos = todos;
        pluginApi.pluginSettings.count = todos.length;

        // Recalculate completed count after removal using helper function
        pluginApi.pluginSettings.completedCount = calculateCompletedCount();
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi?.tr("main.removed_todo"));
      } else {
        Logger.e("Todo", "Todo with ID " + id + " not found");
        ToastService.showError(pluginApi?.tr("main.todo_not_found") + id + pluginApi?.tr("main.not_found_suffix"));
      }
    }
  }

  // Helper function to update a todo's properties
  function updateTodo(todoId, updates) {
    if (!pluginApi) return false;

    var todos = pluginApi.pluginSettings.todos || [];
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].id.toString() === String(todoId)) {
        if (updates.text !== undefined) todos[i].text = updates.text;
        if (updates.completed !== undefined) todos[i].completed = updates.completed;
        if (updates.priority !== undefined) todos[i].priority = updates.priority;
        if (updates.details !== undefined) todos[i].details = updates.details;
        return true;
      }
    }
    return false;
  }

  // Helper function to calculate completed count
  function calculateCompletedCount() {
    if (!pluginApi) return 0;

    var todos = pluginApi.pluginSettings.todos || [];
    var completedCount = 0;
    for (var j = 0; j < todos.length; j++) {
      if (todos[j].completed) {
        completedCount++;
      }
    }
    return completedCount;
  }

  // Helper function to find a todo by ID
  function findTodoById(todoId) {
    var todos = pluginApi.pluginSettings.todos || [];
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].id.toString() === String(todoId)) {
        return todos[i];
      }
    }
    return null;
  }

  // Helper function to validate page ID
  function isValidPageId(pageId) {
    if (!pluginApi) return false;

    var pages = pluginApi.pluginSettings.pages || [];
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].id === pageId) {
        return true;
      }
    }
    return false;
  }

  // Helper function to validate priority
  function validatePriority(priority) {
    var validPriorities = ["high", "medium", "low"];
    if (!priority || validPriorities.indexOf(priority) === -1) {
      return "medium"; // default priority
    }
    return priority;
  }
}
