import { Controller } from "@hotwired/stimulus"

interface SidePanelTargets {
  overlay: HTMLElement
  panel: HTMLElement
  backdrop: HTMLElement
}

export default class extends Controller {
  static targets = ["overlay", "panel", "backdrop"]

  declare readonly overlayTarget: HTMLElement
  declare readonly panelTarget: HTMLElement
  declare readonly backdropTarget: HTMLElement

  connect(): void {
    console.log("Side panel controller connected")
    console.log("Element:", this.element)
    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    console.log("Panel target:", panel)
    console.log("Backdrop target:", backdrop)
    console.log("Initial panel classes:", panel.className)
    console.log("Initial backdrop classes:", backdrop.className)
    
    // 初期状態を設定
    this.initializePanel()
    
    // 少し遅延してから表示
    setTimeout(() => {
      this.show()
    }, 10)
  }

  initializePanel(): void {
    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    
    console.log("Initializing panel...")
    console.log("Before - Panel classes:", panel.className)
    console.log("Before - Backdrop classes:", backdrop.className)
    
    // 初期状態ではパネルを画面外に配置
    panel.classList.remove("translate-x-0")
    panel.classList.add("translate-x-full")
    
    // バックドロップを透明に
    backdrop.classList.remove("opacity-50")
    backdrop.classList.add("opacity-0")
    
    console.log("After - Panel classes:", panel.className)
    console.log("After - Backdrop classes:", backdrop.className)
  }

  show(): void {
    // パネルを表示
    console.log("Showing side panel")
    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    
    console.log("Before show - Panel classes:", panel.className)
    console.log("Before show - Backdrop classes:", backdrop.className)
    
    // bodyにクラスを追加してスクロールを無効化
    document.body.classList.add("side-panel-open")
    
    // パネルを表示状態に設定
    panel.classList.remove("translate-x-full")
    panel.classList.add("translate-x-0")
    
    backdrop.classList.remove("opacity-0")
    backdrop.classList.add("opacity-50")
    
    console.log("After show - Panel classes:", panel.className)
    console.log("After show - Backdrop classes:", backdrop.className)
  }

  close(): void {
    // パネルを非表示
    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    
    // bodyからクラスを削除
    document.body.classList.remove("side-panel-open")
    
    panel.classList.remove("translate-x-0")
    panel.classList.add("translate-x-full")
    
    backdrop.classList.remove("opacity-50")
    backdrop.classList.add("opacity-0")
    
    // 少し遅延してから要素を削除
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  // ESCキーで閉じる
  keydown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      this.close()
    }
  }
} 