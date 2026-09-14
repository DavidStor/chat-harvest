'use strict';
// Fictional data only. No requests, storage, tracking, or database access.
const transcript = [
  [false, 'Sunday picnic? The forecast looks perfect ☀️'],
  [true, 'Absolutely. Same park as last time?'],
  [false, 'Yes! Meet by the lake at 2.'],
  [true, "I'll bring a blanket and some apples."],
  [false, "Perfect. I'll make sandwiches and bring apple cider."],
  [true, 'The little bakery on Maple Street was so good last time.'],
  [false, 'Their apple tart is worth the detour.'],
  [true, 'Adding it to the list 📝'],
  [false, '[photo]'],
  [false, 'Found our picnic spot!'],
  [true, 'Looks great. Apples, sandwiches, sunshine. Sorted.']
];
const query = 'apple';
const list = document.querySelector('#messages');
const count = document.querySelector('#match-count');
const previous = document.querySelector('#previous');
const next = document.querySelector('#next');
let marks = [], active = 0;
const bubbles = transcript.map(([me, text]) => {
  const element = document.createElement('p');
  element.className = `bubble${me ? ' me' : ''}`;
  element.setAttribute('aria-label', `${me ? 'Me' : 'Friend'}: ${text}`);
  list.append(element);
  return element;
});
function focusMatch(scroll) {
  marks.forEach((mark, index) => mark.classList.toggle('current', index === active));
  count.textContent = marks.length ? `${active + 1} of ${marks.length}` : 'No matches';
  previous.disabled = next.disabled = !marks.length;
  const mark = marks[active];
  if (scroll && mark) {
    // Scroll only the conversation, never move the whole web page.
    const box = mark.getBoundingClientRect(), viewport = list.getBoundingClientRect();
    list.scrollTop += box.top - viewport.top - list.clientHeight / 2 + box.height / 2;
  }
}
function search(scroll = true) {
  marks = []; active = 0;
  transcript.forEach(([, text], index) => {
    const bubble = bubbles[index]; bubble.replaceChildren();
    const normalized = text.toLocaleLowerCase();
    let cursor = 0, found;
    while (query && (found = normalized.indexOf(query, cursor)) !== -1) {
      bubble.append(document.createTextNode(text.slice(cursor, found)));
      const mark = document.createElement('mark');
      mark.textContent = text.slice(found, found + query.length);
      bubble.append(mark); marks.push(mark); cursor = found + query.length;
    }
    bubble.append(document.createTextNode(text.slice(cursor)));
  });
  focusMatch(scroll);
}
function move(step) { if (marks.length) { active = (active + step + marks.length) % marks.length; focusMatch(true); } }
previous.addEventListener('click', () => move(-1)); next.addEventListener('click', () => move(1));
search(false);
