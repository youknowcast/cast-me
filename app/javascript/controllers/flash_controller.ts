import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  connect() {
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  dismiss() {
    // Add fade-out class
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500")
    
    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }
}
