import { LightningElement, api } from 'lwc';

export default class CpqCanvas extends LightningElement {
    @api labels;
    @api currentLang = 'en';
    @api canvasItems = [];
    @api selectedCurrency = 'MAD';

    get lbl() {
        return this.labels ? this.labels[this.currentLang] : {};
    }

    handleClearCanvas() {
        this.dispatchEvent(new CustomEvent('clearcanvas'));
    }

    handleCanvasDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        event.currentTarget.classList.add('cpq-canvas-dragover');
    }

    handleCanvasDragLeave(event) {
        event.currentTarget.classList.remove('cpq-canvas-dragover');
    }

    handleCanvasDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('cpq-canvas-dragover');
        const raw = event.dataTransfer.getData('text/plain');
        if (!raw) return;
        
        let drop;
        try { drop = JSON.parse(raw); } catch (e) { return; }
        
        const rect = event.currentTarget.getBoundingClientRect();
        const style = `left:${event.clientX - rect.left}px;top:${event.clientY - rect.top}px;`;

        this.dispatchEvent(new CustomEvent('canvasdrop', {
            detail: { dropData: drop, style: style }
        }));
    }

    handleCanvasItemMouseDown(event) {
        const item = event.currentTarget;
        const sx = event.clientX - item.offsetLeft;
        const sy = event.clientY - item.offsetTop;
        const mv = e => { item.style.left = (e.clientX - sx) + 'px'; item.style.top = (e.clientY - sy) + 'px'; };
        const up = () => { document.removeEventListener('mousemove', mv); document.removeEventListener('mouseup', up); };
        document.addEventListener('mousemove', mv);
        document.addEventListener('mouseup', up);
    }

    handleQuantityChange(event) {
        const uid = event.currentTarget.dataset.uid;
        const qty = Math.max(1, parseInt(event.currentTarget.value, 10) || 1);
        this.dispatchEvent(new CustomEvent('quantitychange', { detail: { uid, qty } }));
    }

    handleManualDiscountChange(event) {
        const uid = event.currentTarget.dataset.uid;
        const disc = parseFloat(event.currentTarget.value) || 0;
        this.dispatchEvent(new CustomEvent('manualdiscountchange', { detail: { uid, disc } }));
    }

    handleCanvasItemRemove(event) {
        const uid = event.currentTarget.dataset.uid;
        this.dispatchEvent(new CustomEvent('itemremove', { detail: { uid } }));
    }

    handleModifyBundle(event) {
        const uid = event.currentTarget.dataset.uid;
        this.dispatchEvent(new CustomEvent('modifybundle', { detail: { uid } }));
    }
}
