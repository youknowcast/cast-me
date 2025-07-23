import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets: string[] = []

  connect(): void {
    console.log("Calendar day controller connected")
  }

  selectDate(event: Event): void {
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date
    console.log("Selected date:", date)
    
    if (!date) {
      console.error("Date not found in dataset")
      return
    }
    
    // Turbo Streamで日別ビューを更新
    const url = `/calendar/daily_view?date=${date}`
    
    fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then((response: Response) => response.text())
    .then((html: string) => {
      // Turbo Streamのレスポンスを処理
      Turbo.renderStreamMessage(html)
    })
    .catch((error: Error) => {
      console.error("Error fetching daily view:", error)
    })
  }
} 