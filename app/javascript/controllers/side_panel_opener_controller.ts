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
    const scope = this.getScope()
    this.openSidePanel(`/plans/new?date=${date}&scope=${scope}`)
  }

  openTaskForm(): void {
    const date = (this.element as HTMLElement).dataset.date
    const scope = this.getScope()
    this.openSidePanel(`/tasks/new?date=${date}&scope=${scope}`)
  }
  openMonthlyList(): void {
    const date = (this.element as HTMLElement).dataset.date
    this.openSidePanel(`/calendar/monthly_list?date=${date}`)
  }

  openPlanEdit(): void {
    const planId = (this.element as HTMLElement).dataset.planId
    this.openSidePanel(`/plans/${planId}/edit`)
  }

  openTaskEdit(): void {
    const taskId = (this.element as HTMLElement).dataset.taskId
    const scope = this.getScope()
    this.openSidePanel(`/tasks/${taskId}/edit?scope=${scope}`)
  }

  // 汎用的なURLオープナー
  openUrl(event: Event): void {
    event.preventDefault()
    const url = (event.currentTarget as HTMLElement).dataset.url || (event.currentTarget as HTMLAnchorElement).href
    if (url) {
      this.openSidePanel(url)
    }
  }

  private getScope(): string {
    const scope = (this.element as HTMLElement).dataset.scope
    if (!scope || scope === 'undefined' || scope === 'null') {
      return 'family'
    }
    return scope
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