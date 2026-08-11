// ============================================================================
// GSP126 - Using the Natural Language API from Google Docs
// Apps Script to paste into: Google Doc -> Extensions -> Apps Script
//
// TASK 3: paste the WHOLE file as-is (retrieveSentiment is a stub returning
//         0.0). Save, reload the doc, select text, use the
//         "Natural Language Tools > Mark Sentiment" menu, authorize, and the
//         selected text becomes highlighted in yellow (= neutral).
//
// TASK 4: replace YOUR_API_KEY below with the API key from Task 2.
// ============================================================================

/** @OnlyCurrentDoc */

//  TASK 3: leave this key as a placeholder.
//  TASK 4: replace with your real API key, e.g.  "AIzaSy..."
var API_KEY = "YOUR_API_KEY"; // <-- paste your API key here

/** Creates a menu entry in the Google Docs UI when the document is opened. */
function onOpen() {
  var ui = DocumentApp.getUi();
  ui.createMenu('Natural Language Tools')
    .addItem('Mark Sentiment', 'markSentiment')
    .addToUi();
}

/** Highlights the selected text by sentiment (green/red/yellow). */
function markSentiment() {
  var POSITIVE_COLOR = '#00ff00'; // colors for sentiments
  var NEGATIVE_COLOR = '#ff0000';
  var NEUTRAL_COLOR = '#ffff00';
  var NEGATIVE_CUTOFF = -0.2; // thresholds for sentiments
  var POSITIVE_CUTOFF = 0.2;

  var selection = DocumentApp.getActiveDocument().getSelection();
  if (selection) {
    var string = getSelectedText();
    var sentiment = retrieveSentiment(string);

    var color = NEUTRAL_COLOR;
    if (sentiment <= NEGATIVE_CUTOFF) {
      color = NEGATIVE_COLOR;
    }
    if (sentiment >= POSITIVE_CUTOFF) {
      color = POSITIVE_COLOR;
    }

    var elements = selection.getSelectedElements();
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].isPartial()) {
        var element = elements[i].getElement().editAsText();
        var startIndex = elements[i].getStartOffset();
        var endIndex = elements[i].getEndOffsetInclusive();
        element.setBackgroundColor(startIndex, endIndex, color);
      } else {
        var el = elements[i].getElement().editAsText();
        el.setBackgroundColor(color);
      }
    }
  }
}

/** Returns a string with the contents of the selected text. */
function getSelectedText() {
  var selection = DocumentApp.getActiveDocument().getSelection();
  var string = "";
  if (selection) {
    var elements = selection.getSelectedElements();
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].isPartial()) {
        var element = elements[i].getElement().asText();
        var startIndex = elements[i].getStartOffset();
        var endIndex = elements[i].getEndOffsetInclusive() + 1;
        var text = element.getText().substring(startIndex, endIndex);
        string = string + text;
      } else {
        var element = elements[i].getElement();
        if (element.editAsText) {
          string = string + element.asText().getText();
        }
      }
    }
  }
  return string;
}

/**
 * Calls the Natural Language API and returns the sentiment score (-1..1).
 */
function retrieveSentiment(line) {
  var apiEndpoint =
    "https://language.googleapis.com/v1/documents:analyzeSentiment?key=" + API_KEY;

  var docDetails = {
    language: 'en-us',
    type: 'PLAIN_TEXT',
    content: line
  };

  var nlData = {
    document: docDetails,
    encodingType: 'UTF8'
  };

  var nlOptions = {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(nlData)
  };

  var response = UrlFetchApp.fetch(apiEndpoint, nlOptions);
  var data = JSON.parse(response);

  var sentiment = 0.0;
  if (data && data.documentSentiment && data.documentSentiment.score) {
    sentiment = data.documentSentiment.score;
  }
  return sentiment;
}