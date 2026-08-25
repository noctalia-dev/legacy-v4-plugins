pragma Singleton
import QtQuick

QtObject {
  function i(tag, msg) { console.log(`[I] ${tag}: ${msg}`) }
  function d(tag, msg) { console.log(`[D] ${tag}: ${msg}`) }
  function w(tag, msg) { console.log(`[W] ${tag}: ${msg}`) }
  function e(tag, msg) { console.log(`[E] ${tag}: ${msg}`) }
}
