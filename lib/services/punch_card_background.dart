const oceanPunchCardBackgroundSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="933" height="589" viewBox="0 0 933 589">
  <rect width="933" height="589" rx="20" fill="#174978"/>
  <rect x="28" y="28" width="877" height="533" rx="16" fill="#E9F7FC"/>
  <path d="M28 398 Q150 333 310 408 T600 414 T905 380 V545 Q905 561 889 561 H44 Q28 561 28 545 Z" fill="#B9E5F3"/>
  <path d="M28 475 Q153 405 311 481 T600 487 T905 454 V545 Q905 561 889 561 H44 Q28 561 28 545 Z" fill="#98D0E6"/>
</svg>
''';

const sunsetPunchCardBackgroundSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="933" height="589" viewBox="0 0 933 589">
  <rect width="933" height="589" rx="20" fill="#9D432B"/>
  <rect x="28" y="28" width="877" height="533" rx="16" fill="#FFF4DF"/>
  <circle cx="730" cy="347" r="115" fill="#FFD381"/>
  <path d="M28 561 V456 L240 361 L427 469 L608 404 L905 500 V561 Z" fill="#FFD9B5"/>
  <path d="M28 561 V519 L227 455 L432 528 L685 455 L905 530 V561 Z" fill="#FFC1A9"/>
</svg>
''';

const inkSaverPunchCardBackgroundSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="933" height="589" viewBox="0 0 933 589">
  <rect x="3" y="3" width="927" height="583" rx="17" fill="#FFFFFF" stroke="#444444" stroke-width="6"/>
</svg>
''';

const _starPath =
    'M798 328 L846 383 L916 361 L883 432 L922 492 '
    'L849 475 L805 548 L794 470 L718 440 L794 402 Z';

// Vector artwork keeps the decoration sharp at the physical card size.
const punchCardBackgroundSvg =
    '''
<svg xmlns="http://www.w3.org/2000/svg" width="933" height="589" viewBox="0 0 933 589">
  <defs>
    <clipPath id="star-hatching"><path d="$_starPath"/></clipPath>
  </defs>
  <rect width="933" height="589" rx="20" fill="#006F64"/>
  <rect x="36" y="36" width="861" height="517" rx="24" fill="#DFF2E9"/>
  <g transform="translate(-48 -17) scale(1.06 1.12)">
    <path fill="#CDD6F1" d="M0 119
    C4 79 44 32 83 29 C122 22 135 58 152 93
    C171 135 207 120 231 115 C282 103 320 154 331 208
    C350 290 302 340 253 340 C197 345 174 315 130 301
    C89 287 54 306 28 274 C13 254 22 211 11 174
    C6 156 0 135 0 119 Z"/>
  </g>
  <g transform="translate(-115 10) scale(1.15 1.16)">
    <path fill="#CBD5FF" d="M565 400
    C550 375 570 354 592 350 C638 338 657 359 697 343
    C735 334 711 297 759 268 C799 237 830 241 869 261
    C905 282 931 296 915 335 C904 368 874 369 866 406
    C854 443 825 435 796 448 C774 456 771 470 738 479
    C693 490 677 445 643 436 C615 428 576 449 565 418 Z"/>
  </g>
  <g transform="translate(-152 -13) scale(1.2)">
    <g stroke="#FF6B45" stroke-width="11" stroke-linecap="round" clip-path="url(#star-hatching)">
    <path d="M700 520 L875 320 M725 535 L900 335 M750 550 L925 350
      M775 565 L950 365 M800 580 L975 380"/>
  </g>
  <path d="$_starPath" fill="none" stroke="#FF6B45" stroke-width="14"
    stroke-linecap="round" stroke-linejoin="round"/>
  </g>
  <g transform="translate(10 -10)">
  <g fill="none" stroke="#FFD15B" stroke-width="5" stroke-linecap="round">
    <path d="M82 446 L76 500 M62 474 L96 474 M66 458 L91 488 M66 488 L88 459"/>
    <path d="M139 500 L135 539 M119 518 L153 518 M124 504 L148 532 M124 532 L148 504"/>
  </g>
  <g fill="#FFD15B">
    <circle cx="52" cy="504" r="3"/><circle cx="97" cy="522" r="3"/>
    <circle cx="114" cy="475" r="3"/><circle cx="165" cy="497" r="3"/>
  </g>
  </g>
</svg>
''';
