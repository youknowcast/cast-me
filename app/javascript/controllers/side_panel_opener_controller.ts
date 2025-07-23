import { Controller } from "@hotwired/stimulus"

declare global {
  interface Window {
    Turbo: {
      renderStreamMessage: (html: string) => void
    }
  }
}

export default class extends Controller {
  static targets = []

  connect(): void {
    console.log("Side panel opener controller connected")
  }

  openPlanForm(): void {
    const date = (this.element as HTMLElement).dataset.date
    this.openSidePanel(`/plans/new?date=${date}`)
  }

  openTaskForm(): void {
    const date = (this.element as HTMLElement).dataset.date
    this.openSidePanel(`/tasks/new?date=${date}`)
  }

  openPlanEdit(): void {
    const planId = (this.element as HTMLElement).dataset.planId
    this.openSidePanel(`/plans/${planId}/edit`)
  }

  openTaskEdit(): void {
    const taskId = (this.element as HTMLElement).dataset.taskId
    this.openSidePanel(`/tasks/${taskId}/edit`)
  }

  private openSidePanel(url: string): void {
    // Turbo Streamリクエストを送信
    fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then((response: Response) => response.text())
    .then((html: string) => {
      // Turbo Streamのレスポンスを処理
      if (typeof window.Turbo !== 'undefined') {
        window.Turbo.renderStreamMessage(html)
      }
    })
    .catch((error: Error) => {
      console.error("Error opening side panel:", error)
    })
  }
} 