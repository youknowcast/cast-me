import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets: string[] = []

  connect(): void {
    console.log("Modal controller connected")
  }

  close(): void {
    // モーダルを閉じる
    const modal = this.element.closest('.modal') as HTMLElement | null
    if (modal) {
      modal.classList.remove('modal-open')
    }
    
    // モーダルコンテンツをクリア
    const modalContent = document.getElementById('modal')
    if (modalContent) {
      modalContent.innerHTML = ''
    }
  }

  open(): void {
    // モーダルを開く
    const modal = this.element.closest('.modal') as HTMLElement | null
    if (modal) {
      modal.classList.add('modal-open')
    }
  }
} 