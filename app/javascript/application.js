// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// Import and register all your controllers from the importmap under controllers/**/*_controller
import CalendarDayController from "./controllers/calendar_day_controller"
import ModalController from "./controllers/modal_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

application.register("calendar-day", CalendarDayController)
application.register("modal", ModalController)
