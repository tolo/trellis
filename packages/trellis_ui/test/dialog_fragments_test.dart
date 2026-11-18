import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  test('dialog and alert dialog render their contract markup', () async {
    final engine = Trellis(loader: TrellisUiLoader(), strict: true);

    void checkNameAndDescription(Element dialog, String id, String title, String description) {
      expect(dialog.attributes['aria-modal'], 'true');
      expect(dialog.attributes['aria-labelledby'], '$id-title');
      expect(dialog.querySelector('#$id-title')?.text, title);
      expect(dialog.attributes['aria-describedby'], '$id-description');
      expect(dialog.querySelector('#$id-description')?.text, description);
    }

    final markup = engine.render('''
<div tl:replace="~{trellis-ui/dialog :: dialog('edit', 'Edit profile', 'Update your details.')}"
    class="app-dialog" data-return-focus="edit-trigger">
  <tl:block tl:slot="trigger"><button id="edit-trigger">Edit</button></tl:block>
  <input name="nickname" aria-label="Nickname">
  <tl:block tl:slot="footer"><button data-dialog-close>Save</button></tl:block>
</div>
<div tl:replace="~{trellis-ui/alert-dialog :: alertDialog('confirm', 'Delete profile?', 'This cannot be undone.', true)}">
  <tl:block tl:slot="trigger"><button>Delete</button></tl:block>
  <tl:block tl:slot="action"><button hx-post="/delete">Confirm</button></tl:block>
</div>''', {});
    expect(markup, isNot(contains('tl:')));
    final document = parseFragment(markup);
    expect(document.querySelectorAll('tl-dialog'), hasLength(2));
    final dialog = document.querySelector('dialog#edit')!;
    checkNameAndDescription(dialog, 'edit', 'Edit profile', 'Update your details.');
    expect(dialog.attributes.containsKey('open'), false);
    expect(dialog.classes, containsAll(['trellis-dialog-content', 'app-dialog']));
    expect(dialog.attributes['data-return-focus'], 'edit-trigger');
    expect(dialog.querySelector('#edit-trigger'), isNull);
    expect(dialog.parent!.querySelector('#edit-trigger')?.text, 'Edit');
    expect(dialog.querySelector('input[name=nickname]'), isNotNull);
    expect(dialog.querySelector('[data-slot=dialog-footer] > button')?.text, 'Save');
    expect(dialog.querySelector('[data-slot=dialog-close][aria-label=Close] > svg[aria-hidden=true]'), isNotNull);

    final alert = document.querySelector('dialog#confirm')!;
    checkNameAndDescription(alert, 'confirm', 'Delete profile?', 'This cannot be undone.');
    expect(alert.attributes['role'], 'alertdialog');
    expect(alert.attributes['open'], '');
    expect(alert.querySelector('[data-slot=dialog-close]'), isNull);
    expect(alert.querySelector('[data-slot=alert-dialog-cancel][autofocus]')?.text.trim(), 'Cancel');
    final action = alert.querySelector('[data-slot=alert-dialog-action] button')!;
    expect(action.text, 'Confirm');
    expect(action.attributes['hx-post'], '/delete');

    final response = parseFragment(
      await engine.renderFileFragment(
        'trellis-ui/alert-dialog',
        fragment: 'alertDialog',
        context: {'id': 'response', 'title': 'Continue?', 'description': 'Your edits will be saved.', 'open': true},
      ),
    );
    final mounted = response.querySelector('dialog#response[open]')!;
    checkNameAndDescription(mounted, 'response', 'Continue?', 'Your edits will be saved.');
    expect(mounted.querySelector('[data-slot=alert-dialog-action] button')?.text.trim(), 'Continue');
  });
}
