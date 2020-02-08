window.onload = function () {
    const input = document.getElementById('count-square');
    const arrColorBackground = [
        'rgba(200,195,195,0.5)',
        'rgba(255,220,0,0.5)',
        'rgba(255,20,75,0.5)',
        'rgba(133,13,195,0.5)',
        'rgba(63,195,238,0.5)',
        'rgba(0,116,217,0.5)',
        'rgba(71,178,5,0.5)',
        'rgba(244,163,12,0.5)',
        'rgba(57,204,204,0.5)',
        'rgba(61,153,112,0.5)',
        'rgba(46,204,64,0.5)',
        'rgba(175,126,108,0.5)',
        'rgba(170,166,239,0.5)', // max
    ];

    const squareInfo = class {
        constructor(id) {
            this.id = id;
            this.timesClicked = 0;
            this.backgroundColor = arrColorBackground[0]; // default
        }
    }
    let arrSquare = [];

    input.onkeyup = () => {
        this.document.querySelector('.error-input').innerHTML = '';
        if (input.value !== '') {
            const num = +input.value;
            if (typeof num === 'number' && num > 0) {
                renderDomByCount(num);
            } else {
                clearDom();
                this.document.querySelector('.error-input').innerHTML = 'Number > 0, please!';
            }
        } else {
            clearDom();
        }
    };

    function clearDom() {
        document.querySelector('.square-container').innerHTML = '';
        arrSquare = [];
    }

    function renderDomByCount(count) {
        clearDom();
        let str = '';
        for (let i = 0; i < count; i++) {
            str += `<div class='square square-${i}' data-idsq='${i}'>
                        
                    </div>`;
            const obj = new squareInfo(i);
            arrSquare.push(obj);
        }
        document.querySelector('.square-container').innerHTML = str;

        // listener event
        document.querySelectorAll('.square').forEach((dom) => {
            dom.addEventListener('click', handleClickSquare, true);
        })
    }

    function handleClickSquare(event) {
        const index = event.target.dataset.idsq;
        const item = arrSquare[index];
        item.timesClicked++;
        item.backgroundColor = arrColorBackground[item.timesClicked] || arrColorBackground[arrColorBackground.length - 1];
        updateDomByIndex(arrSquare[index])
    }

    function updateDomByIndex(item) {
        const square = document.querySelector(`.square.square-${item.id}`);
        square.innerHTML = '';

        // create child
        const span = document.createElement('span');
        span.dataset.idsq = item.id;
        span.textContent = `Clicked ${item.timesClicked} times`;
        square.appendChild(span);
        square.style.backgroundColor = item.backgroundColor;
    }
};