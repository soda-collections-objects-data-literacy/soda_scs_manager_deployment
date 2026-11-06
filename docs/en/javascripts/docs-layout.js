/* Stacks a screenshot above its description and keeps the dashboard button in columns 9–10. */
(function () {
  var article = document.querySelector(".md-content__inner.md-typeset");
  if (!article) {
    return;
  }

  var userDoc = /\/user(\/|$)/.test(location.pathname);
  if (userDoc) {
    document.body.classList.add("scs-user-doc");
  }

  article.querySelectorAll(":scope > p").forEach(function (paragraph) {
    var image = paragraph.querySelector(":scope > img:only-child");
    if (!image) {
      return;
    }
    var figure = document.createElement("figure");
    figure.className = "scs-figure";
    var caption = document.createElement("figcaption");
    caption.textContent = image.getAttribute("alt") || "";
    figure.appendChild(image);
    if (caption.textContent) {
      figure.appendChild(caption);
    }
    paragraph.replaceWith(figure);
  });

  article.querySelectorAll(":scope > .scs-cta").forEach(function (action) {
    var previous = action.previousElementSibling;
    while (previous && (previous.id === "__skip" || previous.classList.contains("scs-figure") || previous.classList.contains("scs-content-search"))) {
      previous = previous.previousElementSibling;
    }
    if (!previous) {
      return;
    }
    var row = window.getComputedStyle(previous).gridRowStart;
    if (row && row !== "auto") {
      action.style.gridRow = row;
    }
  });
})();
