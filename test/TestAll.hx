import utest.Runner;
import utest.ui.Report;

class TestAll {
  public static function main() {
    utest.UTest.run([new TestCase()]);
  }
}
